#!/usr/bin/env python3
"""Serve the Herdr App socket to one jail: programs run in its Core, the App only shows them."""

import argparse
import json
import os
import re
import signal
import socket
import stat
import struct
import sys
import tempfile

from server import RelayError, decode, denied, encode, invalid, receive_line, stop


MAX_REPLY = 8 << 20
APP_TIMEOUT = 35.0
TERMINAL_ID = re.compile(r"t[0-9a-z]+")
TERM_ENV = {"TERM": "xterm-256color", "COLORTERM": "truecolor", "TERM_PROGRAM": "herdr"}

# Commands that only change what the window shows.
VIEW = {
    "space.rename", "space.move", "space.select", "space.next", "space.prev",
    "tab.rename", "tab.move", "tab.select", "tab.settle", "tab.unsettle", "tab.next", "tab.prev",
    "pane.zoom", "pane.focus", "pane.go", "pane.swap",
    "terminal.right_click", "terminal.peek", "terminal.show",
    "agent.focus", "agent.next", "agent.prev",
    "layout.switch", "layout.toggle", "layout.show", "layout.hide", "layout.resize", "layout.select",
    "overlay.close", "app.help", "app.welcome", "app.whats_new", "app.palette",
    "app.zoom_in", "app.zoom_out", "app.zoom_reset", "window.minimize", "window.maximize",
}
# Commands that end or move host terminals: only targets this proxy created.
OWNED = {
    "space.close": ("id", "space"), "tab.close": ("id", "tab"), "pane.close": ("pane", "pane"),
    "terminal.kill": ("terminal", "terminal"), "terminal.keep": ("terminal", "terminal"),
    "terminal.park": ("terminal", "terminal"),
}
# Commands that start a program, and the arguments each may pass through to the App.
SPAWN = {
    "space.new": {"name", "folder", "tab"},
    "tab.new": {"name", "space", "folder"},
    "pane.split": {"direction", "pane"},
    "terminal.open": {"folder", "place", "name"},
}
QUERIES = {"ls", "status", "commands", "raise"}


def call(path, request, timeout, host_ns=None):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(timeout)
        connection.connect(path)
        # The jail owns the path and could link it to the host Core; check who answered.
        if host_ns:
            pid = struct.unpack("3i", connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))[0]
            if os.readlink(f"/proc/{pid}/ns/pid") == host_ns:
                raise ValueError("Core runs outside the jail")
        connection.sendall(encode(request))
        data = bytearray()
        while not data.endswith(b"\n"):
            chunk = connection.recv(65_536)
            if not chunk or len(data) + len(chunk) > MAX_REPLY:
                raise ValueError("incomplete reply")
            data.extend(chunk)
        return json.loads(data)


def write_png(root, path, data):
    """Write below root without following a symlink the jail could swap in."""
    if not isinstance(path, str) or not path.lower().endswith(".png"):
        invalid("screenshot path must end in .png")
    parts = os.path.relpath(os.path.normpath(path), root).split(os.sep)
    if not os.path.isabs(path) or parts[0] in (os.curdir, os.pardir):
        denied("screenshots go inside the workspace")
    fd = os.open(root, os.O_DIRECTORY)
    try:
        for part in parts[:-1]:
            child = os.open(part, os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        out = os.open(parts[-1], os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o644, dir_fd=fd)
        with os.fdopen(out, "wb") as file:
            file.write(data)
    finally:
        os.close(fd)


class AppProxy:
    def __init__(self, args):
        self.app = args.upstream
        self.core = args.core
        self.workspace = os.path.realpath(args.workspace)
        self.parent = os.getppid()
        self.host_ns = os.readlink("/proc/self/ns/pid")
        self.owned = {"space": set(), "tab": set(), "pane": set(), "terminal": set()}

    def app_call(self, request):
        try:
            reply = call(self.app, request, APP_TIMEOUT)
        except (OSError, ValueError, RecursionError):
            raise RelayError("app_unavailable", "no Herdr window answered") from None
        if not isinstance(reply, dict):
            raise RelayError("app_unavailable", "invalid App reply")
        return reply

    def core_call(self, method, params):
        # The jail can replace its own Core, so its replies are untrusted.
        try:
            reply = call(self.core, {"jsonrpc": "2.0", "id": "app-proxy", "method": method, "params": params}, 5.0, self.host_ns)
        except (OSError, ValueError, RecursionError):
            raise RelayError("core_unavailable", "sandbox Core is not running; start it with `hc ls`") from None
        if not isinstance(reply, dict) or not isinstance(reply.get("result"), dict):
            error = reply.get("error") if isinstance(reply, dict) else None
            message = error.get("message") if isinstance(error, dict) else None
            raise RelayError("core_error", str(message or "sandbox Core refused the program"))
        return reply["result"]

    def handle(self, request):
        if not isinstance(request, dict) or len(request) != (2 if "args" in request else 1):
            denied("expected one of do, ls, status, commands, raise or shot")
        if "shot" in request:
            return self.shot(request["shot"])
        key = next(key for key in request if key != "args")
        if key in QUERIES:
            return self.app_call({key: True})
        if key != "do" or not isinstance(request["do"], str):
            denied("expected one of do, ls, status, commands, raise or shot")
        name, args = request["do"], request.get("args")
        if args is None:
            args = {}
        if not isinstance(args, dict):
            invalid(name + ": arguments must be an object")
        if name in SPAWN:
            return self.spawn(name, args)
        if name in OWNED:
            field, kind = OWNED[name]
            target = args.get(field)
            if not isinstance(target, str) or target not in self.owned[kind]:
                denied(f"{name} needs --{field} naming a {kind} this jail created")
        elif name not in VIEW:
            denied(name + " is not available to sandboxed agents")
        return self.app_call({"do": name, "args": args})

    def spawn(self, name, args):
        extra = set(args) - SPAWN[name] - {"argv", "task"}
        if extra:
            denied(f"{name}: {', '.join(sorted(extra))} not available to sandboxed agents")
        argv = args.get("argv") or []
        if not isinstance(argv, list) or not all(isinstance(item, str) for item in argv):
            invalid("argv must be a list of strings")
        task = args.get("task")
        if argv and isinstance(task, str) and task.strip():
            argv = [*argv, task.strip()]
        folder = args.get("folder")
        if folder is not None and (not isinstance(folder, str) or not os.path.isabs(folder)):
            invalid("folder must be an absolute path")
        params = {"cwd": folder or self.workspace, "env": TERM_ENV, "labels": {}}
        if argv:
            params["argv"] = argv
        terminal = self.core_call("terminal.run", params).get("address")
        if not isinstance(terminal, str) or not TERMINAL_ID.fullmatch(terminal):
            raise RelayError("core_error", "sandbox Core returned no terminal")
        forward = {key: value for key, value in args.items() if key in SPAWN[name]}
        # The viewer runs on the host; a jail-only folder would fail its launch there.
        if folder and not os.path.isdir(folder):
            forward.pop("folder", None)
        if name == "terminal.open" and forward.get("place", "tab") == "tab":
            forward.setdefault("name", os.path.basename(argv[0]) if argv else "shell")
        forward["argv"] = ["herdr-core-view", self.core, terminal]
        try:
            reply = self.app_call({"do": name, "args": forward})
        except RelayError:
            reply = None
        if not reply or "error" in reply:
            self.core_call("terminal.kill", {"terminal": terminal})
            return reply or {"error": "no Herdr window answered"}
        for kind in ("tab", "pane", "terminal"):
            if isinstance(reply.get(kind), str):
                self.owned[kind].add(reply[kind])
        # tab.new also answers with the existing space it joined.
        if name == "space.new" and isinstance(reply.get("space"), str):
            self.owned["space"].add(reply["space"])
        return {**reply, "sandbox_terminal": terminal}

    def shot(self, path):
        with tempfile.TemporaryDirectory(prefix="agent-app-shot.") as private:
            reply = self.app_call({"shot": os.path.join(private, "shot.png")})
            if "error" in reply:
                return reply
            try:
                with open(os.path.join(private, "shot.png"), "rb") as file:
                    write_png(self.workspace, path, file.read())
            except OSError as error:
                return {"error": f"cannot save screenshot: {error.strerror}"}
        return {"path": path}

    def tick(self):
        if os.getppid() != self.parent:
            raise SystemExit(0)


def handle(connection, proxy):
    try:
        response = proxy.handle(decode(receive_line(connection)))
    except RelayError as error:
        response = {"error": str(error)}
    except OSError:
        return
    try:
        connection.settimeout(APP_TIMEOUT)
        connection.sendall(encode(response))
    except (OSError, ValueError):
        pass


def serve(listen, proxy):
    owned = None
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            listener.bind(listen)
            created = os.lstat(listen)
            owned = (created.st_dev, created.st_ino)
            os.chmod(listen, 0o600)
            listener.listen(16)
            listener.settimeout(1)
            while True:
                proxy.tick()
                try:
                    connection, _ = listener.accept()
                except TimeoutError:
                    continue
                with connection:
                    handle(connection, proxy)
    finally:
        if owned is not None:
            try:
                current = os.lstat(listen)
                if stat.S_ISSOCK(current.st_mode) and (current.st_dev, current.st_ino) == owned:
                    os.unlink(listen)
            except FileNotFoundError:
                pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen", required=True)
    parser.add_argument("--upstream", required=True)
    parser.add_argument("--core", required=True)
    parser.add_argument("--workspace", required=True)
    args = parser.parse_args()
    if not all(os.path.isabs(path) for path in (args.listen, args.upstream, args.core, args.workspace)):
        parser.error("socket and workspace paths must be absolute")
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    os.umask(0o077)
    try:
        serve(args.listen, AppProxy(args))
    except OSError:
        print("herdr app proxy: listener failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

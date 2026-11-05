#!/usr/bin/env python3
"""Serve the host Core to one jail as the `hc` machine `host`; everything it starts is jailed.

The jail registers this socket with `hc machine add --via`. Each connection runs
`herdr-core connect` against the host Core and rewrites the stream:

- terminal.run starts `claude`/`omp` through their own jail wrappers and every
  other program through the agent-jail-run wrapper, always with host access off,
  so nothing the jail starts here runs unjailed or can answer a host_* prompt.
- Calls on terminals pass only for terminals this jail started and their
  descendants; listings and events show only those.
- machine.exec and file.* are answered by the jail's own Core, which sees the
  same workspace.
- Calls that would run an unjailed host shell or change the host Core itself
  are refused.

Wire format (herdr-core connect): one newline-terminated JSON hello each way,
then frames of `u32le channel | u8 kind | u32le length | payload`. kind 0 is
data, kind 1 a u32le flow-control credit. Channel 0 carries JSON-RPC requests
and replies; event channels carry newline-terminated JSON events that may span
frames.
"""

import argparse
import json
import os
import secrets
import signal
import socket
import stat
import struct
import subprocess
import sys
import threading

from app_proxy import call
from server import stop

HEADER = struct.Struct("<IBI")
CORE_TIMEOUT = 600.0
# Marks host terminals this link started: their `created` event arrives before the run reply.
LABEL = "agent-jail-link"
# Label a run carries to pass this session's signing and push grant to the child.
SIGNING_LABEL = "agent-jail.signing"
# Terminal variables the client sends; anything else would reach the host-side
# wrapper before bubblewrap starts (LD_PRELOAD, BASH_ENV, PATH...).
CLIENT_ENV = {"TERM", "COLORTERM", "TERM_PROGRAM"}
TERMINAL_METHODS = {
    "terminal.get", "terminal.read", "terminal.wait", "terminal.send", "terminal.keys",
    "terminal.interrupt", "terminal.kill", "terminal.rm", "terminal.label",
    "terminal.attach", "terminal.put",
}
PASS_METHODS = {"hello", "rpc.discover", "templates.list", "server.status", "machine.list"}
LISTING_METHODS = {"terminal.list", "events.subscribe"}
JAIL_METHODS = {"machine.exec", "file.read", "file.write", "file.edit"}
REFUSED = {
    "terminal.keep": "it replaces a lost program with an unjailed host shell",
    "server.stop": "it would stop the host Core",
    "server.restart": "it would restart the host Core",
    "machine.add": "it changes the host Core's machines",
    "machine.rm": "it changes the host Core's machines",
    "machine.rename": "it changes the host Core's machines",
    "machine.connect": "it would reach another machine outside any jail",
}


def read_exact(stream, size):
    data = bytearray()
    while len(data) < size:
        chunk = stream.read(size - len(data))
        if not chunk:
            raise EOFError
        data.extend(chunk)
    return bytes(data)


def frame(channel, kind, payload):
    return HEADER.pack(channel, kind, len(payload)) + payload


def dump(value):
    return json.dumps(value, separators=(",", ":")).encode()


class Refused(Exception):
    pass


class HostLink:
    """Rules shared by every connection of one jail; owned terminals outlive reconnects."""

    def __init__(self, args):
        self.workspace = os.path.realpath(args.workspace)
        self.core = args.core
        self.parent = args.parent or None
        self.runner = args.runner
        self.wrappers = dict(item.split("=", 1) for item in args.wrapper)
        self.upstream = args.upstream
        self.signing = args.signing
        self.host_ns = os.readlink("/proc/self/ns/pid")
        self.owned = set()
        self.names = {}  # name -> address, for owned terminals
        self.token = secrets.token_hex(8)
        self.lock = threading.Lock()

    def owns(self, address):
        with self.lock:
            return address in self.owned

    def resolve(self, target):
        """Return the owned address a terminal name or address refers to, or None."""
        with self.lock:
            if target in self.owned:
                return target
            return self.names.get(target)

    def adopt(self, terminal):
        """Keep a terminal dict when this jail started it or one of its descendants."""
        if not isinstance(terminal, dict):
            return False
        with self.lock:
            if terminal.get("address") in self.owned:
                self.remember(terminal)
                return True
            labels = terminal.get("labels")
            mine = isinstance(labels, dict) and labels.get(LABEL) == self.token
            if (mine or terminal.get("parent") in self.owned) and isinstance(terminal.get("address"), str):
                self.owned.add(terminal["address"])
                self.remember(terminal)
                return True
        return False

    def remember(self, terminal):
        # Names are unique among live terminals only; the latest owned holder wins.
        if isinstance(terminal.get("name"), str):
            self.names[terminal["name"]] = terminal["address"]

    def program(self, params):
        """Return the host argv for a run request: a jail wrapper in front of whatever was asked."""
        argv = params.get("argv") or []
        line = params.get("line")
        if not isinstance(argv, list) or not all(isinstance(item, str) for item in argv):
            raise Refused("argv must be a list of strings")
        if line is not None:
            if not isinstance(line, str):
                raise Refused("line must be a string")
            argv = ["sh", "-c", line]
        if argv and argv[0] in self.wrappers:
            return [self.wrappers[argv[0]], *argv[1:]]
        return [self.runner, *argv]

    def chdir(self, cwd):
        """Map a cwd to a path inside the workspace, relative to it.

        The host Core always starts in the workspace root; the wrapper applies the
        rest with bubblewrap --chdir, so a symlink the jail plants resolves inside
        the new jail rather than on the host.
        """
        if cwd is None:
            return "."
        if not isinstance(cwd, str) or not os.path.isabs(cwd):
            raise Refused("cwd must be an absolute path inside the workspace")
        relative = os.path.relpath(os.path.normpath(cwd), self.workspace)
        if relative == os.pardir or relative.startswith(os.pardir + os.sep):
            raise Refused(f"cwd must be inside the workspace {self.workspace}")
        return relative

    def run(self, params):
        if params.get("keep"):
            raise Refused("--keep would replace a lost program with an unjailed host shell")
        relative = self.chdir(params.get("cwd"))
        env = {key: value for key, value in (params.get("env") or {}).items()
               if key in CLIENT_ENV and isinstance(value, str)}
        env["AGENT_JAIL_NO_HOST"] = "1"
        labels = params.get("labels") if isinstance(params.get("labels"), dict) else {}
        if labels.get(SIGNING_LABEL) not in (None, "", "0", "false"):
            # Only the user grants signing, at launch; a session can pass on what it holds.
            if not self.signing:
                raise Refused(f"{SIGNING_LABEL}: this session has no signing grant to pass on")
            env["AGENT_JAIL_SIGNING"] = "1"
        if relative != ".":
            env["AGENT_JAIL_CHDIR"] = relative
        rewritten = {
            key: params[key] for key in ("name", "die_with_parent", "outlive_parent",
                                         "no_notify", "rm", "timeout", "wait")
            if key in params
        }
        rewritten.update(argv=self.program(params), cwd=self.workspace, env=env, keep=False,
                         labels={**labels, LABEL: self.token})
        # Parent is always the jail's own host terminal: never a terminal the jail names.
        if self.parent and not params.get("no_parent"):
            rewritten["parent"] = self.parent
        else:
            rewritten["no_parent"] = True
        return rewritten

    def check(self, request):
        """Return (route, request): route is "core", "jail", or raises Refused."""
        method = request.get("method")
        params = request.get("params")
        if params is None:
            params = {}
        if not isinstance(params, dict):
            raise Refused("params must be an object")
        if method in REFUSED:
            raise Refused(f"{method} is refused because {REFUSED[method]}")
        # The jail must not pose as a host terminal for parent and notes bookkeeping.
        params.pop("caller", None)
        params.pop("on", None)
        if method == "terminal.run":
            params = self.run(params)
        elif method in TERMINAL_METHODS:
            address = self.resolve(params.get("terminal"))
            if address is None:
                raise Refused(f"{params.get('terminal')!r} is not a terminal this jail started on the host")
            # Forward the address: a name could meanwhile belong to someone else's terminal.
            params["terminal"] = address
        elif method in JAIL_METHODS:
            return "jail", {**request, "params": params}
        elif method not in PASS_METHODS | LISTING_METHODS:
            raise Refused(f"{method} is not routed to the host")
        return "core", {**request, "params": params}

    def jail_call(self, request):
        return call(self.core, {"jsonrpc": "2.0", "id": request.get("id"), "method": request["method"],
                                "params": request["params"]}, CORE_TIMEOUT, self.host_ns)


class Connection:
    def __init__(self, link, client):
        self.link = link
        self.client = client
        self.client_in = client.makefile("rb", buffering=0)
        self.client_out = client.makefile("wb", buffering=0)
        self.server = subprocess.Popen(link.upstream, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        self.pending = {}  # request id -> method, for reply rewriting
        self.events = set()  # event channels opened by events.subscribe
        self.partial = {}  # event channel -> unfinished event line
        self.client_lock = threading.Lock()
        self.server_lock = threading.Lock()

    def to_client(self, data):
        with self.client_lock:
            self.client_out.write(data)

    def to_server(self, data):
        with self.server_lock:
            self.server.stdin.write(data)
            self.server.stdin.flush()

    def reply(self, request, body):
        self.to_client(frame(0, 0, dump({"id": request.get("id"), "jsonrpc": "2.0", **body})))

    def refuse(self, request, why):
        print(f"refused {request.get('method')}: {why}", file=sys.stderr, flush=True)
        self.reply(request, {"error": {"code": -32000, "message": f"host link: {why}",
                                       "data": {"kind": "refused", "hint": "see the herdr-core skill"}}})

    def answer_from_jail(self, request):
        try:
            answer = self.link.jail_call(request)
        except (OSError, ValueError, RecursionError):
            return self.refuse(request, "the jail's own Core is not running; start it with `hc ls`")
        answer.pop("id", None)
        answer.pop("jsonrpc", None)
        self.reply(request, answer)

    def request(self, payload):
        request = json.loads(payload)
        if not isinstance(request, dict):
            return
        try:
            route, request = self.link.check(request)
        except Refused as why:
            return self.refuse(request, str(why))
        if route == "jail":
            threading.Thread(target=self.answer_from_jail, args=(request,), daemon=True).start()
            return
        self.pending[request.get("id")] = request["method"]
        self.to_server(frame(0, 0, dump(request)))

    def client_pump(self):
        try:
            self.to_server(self.client_in.readline())
            while True:
                channel, kind, length = HEADER.unpack(read_exact(self.client_in, HEADER.size))
                payload = read_exact(self.client_in, length)
                if channel == 0 and kind == 0:
                    self.request(payload)
                else:
                    # Credits and attach input; channels exist only for allowed requests.
                    self.to_server(frame(channel, kind, payload))
        except (EOFError, OSError, ValueError) as error:
            print(f"client side ended: {error!r}", file=sys.stderr, flush=True)
        finally:
            self.close()

    def events_frame(self, channel, payload):
        # Event channels are byte streams of newline-terminated JSON.
        complete, newline, rest = (self.partial.pop(channel, b"") + payload).rpartition(b"\n")
        if rest:
            self.partial[channel] = rest
        lines = (complete + newline).splitlines(keepends=True)
        kept = b"".join(line for line in lines if self.event_visible(line))
        dropped = sum(map(len, lines)) - len(kept)
        if dropped:
            # Dropped bytes still count against the window: credit them here.
            self.to_server(frame(channel, 1, struct.pack("<I", dropped)))
        if kept:
            self.to_client(frame(channel, 0, kept))

    def event_visible(self, line):
        body = json.loads(line)
        params = body.get("params") if isinstance(body, dict) else None
        if not isinstance(params, dict) or "terminal" not in params:
            return isinstance(body, dict) and body.get("method") == "heartbeat"
        data = params.get("data")
        if params.get("type") == "created" and isinstance(data, dict):
            return self.link.adopt(data)
        return self.link.owns(params.get("terminal"))

    def server_reply(self, payload):
        body = json.loads(payload)
        method = self.pending.pop(body.get("id"), None)
        result = body.get("result")
        if isinstance(result, dict):
            if method == "terminal.run" and isinstance(result.get("address"), str):
                with self.link.lock:
                    self.link.owned.add(result["address"])
                    self.link.remember(result)
            if method in LISTING_METHODS and isinstance(result.get("terminals"), list):
                result["terminals"] = [t for t in result["terminals"] if self.link.adopt(t)]
                payload = dump(body)
            if method == "events.subscribe" and isinstance(result.get("channel"), int):
                self.events.add(result["channel"])
        self.to_client(frame(0, 0, payload))

    def server_pump(self):
        out = self.server.stdout
        try:
            self.to_client(out.readline())
            while True:
                channel, kind, length = HEADER.unpack(read_exact(out, HEADER.size))
                payload = read_exact(out, length)
                if kind == 0 and channel == 0:
                    self.server_reply(payload)
                elif kind == 0 and channel in self.events:
                    self.events_frame(channel, payload)
                else:
                    self.to_client(frame(channel, kind, payload))
        except (EOFError, OSError, ValueError) as error:
            print(f"host side ended: {error!r}", file=sys.stderr, flush=True)
        finally:
            self.close()

    def close(self):
        try:
            # Wakes the other pump, which may be blocked reading this socket.
            self.client.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        for stream in (self.client_out, self.server.stdin):
            try:
                stream.close()
            except OSError:
                pass
        if self.server.poll() is None:
            self.server.terminate()


def serve(listen, link):
    parent = os.getppid()
    owned = None
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            listener.bind(listen)
            created = os.lstat(listen)
            owned = (created.st_dev, created.st_ino)
            os.chmod(listen, 0o600)
            listener.listen(16)
            listener.settimeout(1)
            while os.getppid() == parent:
                try:
                    client, _ = listener.accept()
                except TimeoutError:
                    continue
                client.settimeout(None)
                connection = Connection(link, client)
                threading.Thread(target=connection.client_pump, daemon=True).start()
                threading.Thread(target=connection.server_pump, daemon=True).start()
    finally:
        if owned is not None:
            try:
                current = os.lstat(listen)
                if stat.S_ISSOCK(current.st_mode) and (current.st_dev, current.st_ino) == owned:
                    os.unlink(listen)
            except FileNotFoundError:
                pass


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--listen", required=True)
    parser.add_argument("--core", required=True, help="the jail Core socket, as seen from the host")
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--parent", default="", help="the launcher's host Core terminal, if any")
    parser.add_argument("--runner", required=True, help="jail wrapper for programs without their own")
    parser.add_argument("--wrapper", action="append", default=[], help="NAME=PATH of a program's own jail wrapper")
    parser.add_argument("--signing", action="store_true", help="this session holds the signing and push grant")
    parser.add_argument("upstream", nargs="+", help="command that speaks to the host Core")
    args = parser.parse_args()
    paths = [args.listen, args.core, args.workspace, args.runner, *(w.partition("=")[2] for w in args.wrapper)]
    if not all(os.path.isabs(path) for path in paths):
        parser.error("socket, workspace and wrapper paths must be absolute")
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGHUP, stop)
    os.umask(0o077)
    try:
        serve(args.listen, HostLink(args))
    except OSError as error:
        print(f"host link: listener failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

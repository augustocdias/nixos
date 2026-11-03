#!/usr/bin/env python3
"""Publish only the current agent's display metadata to its Herdr Core terminal."""

import argparse
import fcntl
import json
import math
import os
import re
import signal
import socket
import stat
import sys
import time
import unicodedata
import uuid


MAX_FRAME = 65_536
IO_TIMEOUT = 1.0
TOKEN_KEYS = {"agent", "title", "todo", "sub1", "sub2", "sub3", "submore"}


class RelayError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def invalid(message):
    raise RelayError("invalid_request", message)


def denied(message):
    raise RelayError("relay_denied", message)


def valid_id(value):
    if not isinstance(value, str) or not value:
        return False
    try:
        return len(value.encode("utf-8")) <= 256
    except UnicodeEncodeError:
        return False


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def finite_float(value):
    result = float(value)
    if not math.isfinite(result):
        raise ValueError("non-finite JSON number")
    return result


def reject_constant(value):
    raise ValueError("non-finite JSON number")


def encode(value):
    return (json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":")) + "\n").encode("utf-8")


def decode(frame):
    try:
        value = json.loads(
            frame.decode("utf-8"),
            object_pairs_hook=no_duplicates,
            parse_constant=reject_constant,
            parse_float=finite_float,
        )
        # Reject escaped lone surrogates as well as invalid wire UTF-8.
        encode(value)
        return value
    except (ValueError, UnicodeError, RecursionError, OverflowError):
        invalid("invalid JSON")


def receive_line(connection):
    deadline = time.monotonic() + IO_TIMEOUT
    data = bytearray()
    while len(data) < MAX_FRAME:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            invalid("frame receive deadline exceeded")
        connection.settimeout(remaining)
        try:
            chunk = connection.recv(MAX_FRAME - len(data))
        except TimeoutError:
            invalid("frame receive deadline exceeded")
        if not chunk:
            invalid("incomplete frame")
        data.extend(chunk)
        newline = data.find(b"\n")
        if newline >= 0:
            # Discard trailing bytes; a connection can produce only one report.
            return bytes(data[:newline])
    invalid("frame exceeds 65536 bytes")


def integer(value, minimum, maximum, field):
    if type(value) is not int or not minimum <= value <= maximum:
        invalid("invalid " + field)


def text(value, maximum, field, allowed_controls=()):
    if not isinstance(value, str) or len(value.encode("utf-8")) > maximum:
        invalid("invalid " + field)
    if any(unicodedata.category(char) == "Cc" and char not in allowed_controls for char in value):
        invalid("invalid " + field)


class CoreActivity:
    """One locked launch owns one display-only label, never Core lifecycle state."""

    def __init__(self, args):
        self.upstream = args.upstream
        self.terminal = args.terminal
        self.agent = args.agent
        self.parent = os.getppid()
        self.lock = open(args.lock_file, "a", encoding="utf-8")
        fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.owner = uuid.uuid4().hex
        self.epoch = self.seq = -1
        self.session = None
        self.snapshot = None
        self.updated = self.renewed = 0
        record = self.rpc("terminal.get")
        if record.get("state") != "live" or type(record.get("created_ms")) is not int:
            raise RelayError("invalid_terminal", "Core terminal is not live")
        self.created = record["created_ms"]
        self.pid = record.get("pid")
        self.publish(None, 0)

    def rpc(self, method, **params):
        request = {"jsonrpc": "2.0", "id": self.owner, "method": method,
                   "params": {"terminal": self.terminal, **params}}
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                connection.settimeout(IO_TIMEOUT)
                connection.connect(self.upstream)
                connection.sendall(encode(request))
                reply = decode(receive_line(connection))
            if (not isinstance(reply, dict) or reply.get("jsonrpc") != "2.0"
                    or reply.get("id") != self.owner or "error" in reply
                    or not isinstance(reply.get("result"), dict)):
                raise ValueError("invalid Core reply")
            return reply["result"]
        except (OSError, ValueError, RelayError):
            raise RelayError("upstream_unavailable", "Core reporting failed") from None

    def report(self, request):
        if not isinstance(request, dict) or set(request) != {"id", "method", "params"}:
            denied("unknown request field")
        if not valid_id(request["id"]) or request["method"] != "activity.report":
            denied("only activity.report is allowed")
        p = request["params"]
        if not isinstance(p, dict) or set(p) != {"seq", "epoch", "session", "tokens"}:
            denied("unknown metadata field")
        for field in ("seq", "epoch"):
            integer(p[field], 0, (1 << 64) - 1, field)
        text(p["session"], 512, "session")
        if not p["session"]:
            invalid("empty session")
        if (p["epoch"] < self.epoch or
                (p["epoch"] == self.epoch and (p["session"] != self.session or p["seq"] <= self.seq))):
            denied("stale session or sequence")
        tokens = p["tokens"]
        if not isinstance(tokens, dict) or set(tokens) != TOKEN_KEYS:
            denied("metadata requires the complete token set")
        for value in tokens.values():
            text(value, 320, "token")
            if len(value) > 80:
                invalid("token exceeds 80 characters")
        snapshot = {"version": 1, "owner": self.owner, "agent": self.agent,
                    "session": p["session"], "tokens": tokens}
        now = int(time.time() * 1000)
        self.publish(snapshot if any(tokens.values()) else None, now)
        self.snapshot = snapshot if any(tokens.values()) else None
        self.updated = now
        self.epoch, self.seq, self.session = p["epoch"], p["seq"], p["session"]
        return {"id": request["id"], "result": {"accepted": True}}

    def publish(self, snapshot, updated):
        record = self.rpc("terminal.get")
        if (record.get("state") != "live" or record.get("created_ms") != self.created
                or record.get("pid") != self.pid):
            raise RelayError("terminal_replaced", "Core terminal incarnation changed")
        now = int(time.time() * 1000)
        value = json.dumps({**snapshot, "updated": updated, "expires": min(now + 60_000, updated + 43_200_000)},
                           ensure_ascii=False) if snapshot else ""
        self.rpc("terminal.label", labels={"nix.activity": value})
        self.renewed = time.monotonic()

    def tick(self):
        if os.getppid() != self.parent:
            raise SystemExit(0)
        if self.snapshot is not None and time.monotonic() - self.renewed >= 20:
            self.publish(self.snapshot, self.updated)

    def close(self):
        try:
            if self.snapshot is not None:
                self.publish(None, 0)
        except RelayError:
            pass
        finally:
            self.lock.close()


def handle(connection, core):
    request_id = None
    try:
        request = decode(receive_line(connection))
        if isinstance(request, dict) and valid_id(request.get("id")):
            request_id = request["id"]
        response = core.report(request)
    except RelayError as error:
        response = {"id": request_id, "error": {"code": error.code, "message": str(error)}}
    except OSError:
        return
    try:
        connection.settimeout(IO_TIMEOUT)
        connection.sendall(encode(response))
    except OSError:
        pass


def stop(signum, frame):
    raise SystemExit(0)


def serve(listen, core):
    owned = None
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            # bind refuses an existing pathname; never unlink someone else's socket.
            listener.bind(listen)
            created = os.lstat(listen)
            owned = (created.st_dev, created.st_ino)
            os.chmod(listen, 0o600)
            listener.listen(16)
            listener.settimeout(1)
            while True:
                try:
                    core.tick()
                except RelayError:
                    pass
                try:
                    connection, _ = listener.accept()
                except TimeoutError:
                    continue
                with connection:
                    handle(connection, core)
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
    parser.add_argument("--terminal", required=True)
    parser.add_argument("--agent", choices=("omp", "claude"), required=True)
    parser.add_argument("--lock-file", required=True)
    args = parser.parse_args()
    if not os.path.isabs(args.listen) or not os.path.isabs(args.upstream):
        parser.error("listen and upstream socket paths must be absolute")
    if not os.path.isabs(args.lock_file) or not re.fullmatch(r"t[0-9a-z]+", args.terminal):
        parser.error("Core requires an absolute lock file and local terminal ID")
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    os.umask(0o077)
    core = None
    try:
        core = CoreActivity(args)
        serve(args.listen, core)
    except (OSError, RelayError):
        print("herdr relay: listener failed", file=sys.stderr)
        return 1
    finally:
        if core is not None:
            core.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())

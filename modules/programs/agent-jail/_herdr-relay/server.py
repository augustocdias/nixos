#!/usr/bin/env python3
"""Relay only the current agent's sidebar and built-in resume reports to Herdr."""

import argparse
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


MAX_FRAME = 65_536
IO_TIMEOUT = 1.0
TOKEN_KEYS = {"agent", "title", "todo", "sub1", "sub2", "sub3", "submore"}
STATES = {"idle", "working", "blocked", "unknown"}
START_SOURCES = {"startup", "resume", "clear", "compact", "branch", "new", "fork", "select"}
SESSION_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*", re.ASCII)


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


def validate_request(request, pane_id, agent):
    if not isinstance(request, dict):
        invalid("request must be an object")
    if set(request) - {"id", "method", "params"}:
        denied("unknown request field")
    if set(request) != {"id", "method", "params"} or not valid_id(request.get("id")):
        invalid("request requires id, method and params")
    method = request["method"]
    params = request["params"]
    if not isinstance(method, str) or not isinstance(params, dict):
        invalid("invalid method or params")
    required = {"pane_id", "source"}
    optional = {"seq"}
    if method == "pane.report_metadata":
        required |= {"tokens"}
        optional |= {"ttl_ms"}
        source = "user:" + agent + "-activity"
    elif method == "pane.report_agent" and agent == "omp":
        required |= {"agent", "state"}
        optional |= {"message", "agent_session_id", "agent_session_path"}
        source = "herdr:" + agent
    elif method == "pane.report_agent_session":
        required |= {"agent"}
        optional |= {"agent_session_id", "agent_session_path", "session_start_source"}
        source = "herdr:" + agent
    else:
        denied("method is not allowed")
    if set(params) - required - optional:
        denied("report field is not allowed")
    if not required <= set(params):
        invalid("missing required report field")
    if params["pane_id"] != pane_id or params["source"] != source:
        denied("report identity does not match this relay")
    if "agent" in required and params["agent"] != agent:
        denied("report agent does not match this relay")

    # Fresh dictionaries prevent unvalidated fields and optional nulls crossing the boundary.
    clean = {key: value for key, value in params.items() if value is not None}
    if "seq" in clean:
        integer(clean["seq"], 0, (1 << 64) - 1, "seq")
    if method == "pane.report_metadata":
        tokens = params["tokens"]
        if not isinstance(tokens, dict):
            invalid("tokens must be an object")
        if set(tokens) - TOKEN_KEYS:
            denied("metadata token is not allowed")
        for value in tokens.values():
            if value is not None and (not isinstance(value, str) or len(value) > 80):
                invalid("invalid metadata token")
        clean["tokens"] = dict(tokens)
        if "ttl_ms" in clean:
            integer(clean["ttl_ms"], 1, 86_400_000, "ttl_ms")
    else:
        if "state" in required:
            if not isinstance(params["state"], str) or params["state"] not in STATES:
                invalid("invalid state")
        if "message" in clean:
            text(clean["message"], 4096, "message", ("\t", "\n"))
        if "session_start_source" in clean:
            start = clean["session_start_source"]
            if not isinstance(start, str) or start not in START_SOURCES:
                invalid("invalid session_start_source")
        if "agent_session_id" in clean:
            session_id = clean["agent_session_id"]
            if not isinstance(session_id, str) or len(session_id) > 512 or SESSION_ID.fullmatch(session_id) is None:
                invalid("invalid agent_session_id")
        if "agent_session_path" in clean:
            path = clean["agent_session_path"]
            text(path, 4096, "agent_session_path")
            if not os.path.isabs(path):
                invalid("agent_session_path must be absolute")
            if agent == "claude":
                del clean["agent_session_path"]
        if method == "pane.report_agent_session":
            if "agent_session_id" not in clean and not (agent == "omp" and "agent_session_path" in clean):
                invalid("report requires a usable session reference")
    return {"id": request["id"], "method": method, "params": clean}


def forward(request, upstream):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(IO_TIMEOUT)
            connection.connect(upstream)
            connection.settimeout(IO_TIMEOUT)
            connection.sendall(encode(request))
            response = decode(receive_line(connection))
        if not isinstance(response, dict) or response.get("id") != request["id"]:
            raise ValueError("invalid response identity")
        if set(response) == {"id", "result"}:
            if not isinstance(response["result"], dict):
                raise ValueError("invalid result")
        elif set(response) == {"id", "error"}:
            error = response["error"]
            if not isinstance(error, dict) or not isinstance(error.get("code"), str) or not isinstance(error.get("message"), str):
                raise ValueError("invalid error")
        else:
            raise ValueError("invalid response fields")
        if len(encode(response)) > MAX_FRAME:
            raise ValueError("response exceeds frame limit")
        return response
    except (OSError, RelayError, ValueError, RecursionError, OverflowError):
        raise RelayError("upstream_unavailable", "upstream transport or response failed") from None


def handle(connection, upstream, pane_id, agent):
    request_id = None
    try:
        request = decode(receive_line(connection))
        if isinstance(request, dict) and valid_id(request.get("id")):
            request_id = request["id"]
        request = validate_request(request, pane_id, agent)
        response = forward(request, upstream)
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


def serve(listen, upstream, pane_id, agent):
    owned = None
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            # bind refuses an existing pathname; never unlink someone else's socket.
            listener.bind(listen)
            created = os.lstat(listen)
            owned = (created.st_dev, created.st_ino)
            os.chmod(listen, 0o600)
            listener.listen(16)
            while True:
                connection, _ = listener.accept()
                with connection:
                    handle(connection, upstream, pane_id, agent)
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
    parser.add_argument("--pane-id", required=True)
    parser.add_argument("--agent", choices=("omp", "claude"), required=True)
    args = parser.parse_args()
    if not os.path.isabs(args.listen) or not os.path.isabs(args.upstream):
        parser.error("listen and upstream socket paths must be absolute")
    if not args.pane_id:
        parser.error("pane ID must not be empty")
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    os.umask(0o077)
    try:
        serve(args.listen, args.upstream, args.pane_id, args.agent)
    except OSError:
        print("herdr relay: listener failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

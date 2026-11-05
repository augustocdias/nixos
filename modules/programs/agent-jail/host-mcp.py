"""host_* tools as a stdio MCP server for the jailed harnesses.

Exposes the four tools over JSON-RPC and forwards each call to host-query as
one JSON line on the HOST_QUERY_SOCKET Unix socket. Approval is the harness's
job: Claude Code lists these tools under permissions.ask, which prompts on
every call even when an allow rule also matches.

No dependencies on purpose: the protocol subset needed here is
initialize / tools/list / tools/call over newline-delimited JSON.
"""

import json
import os
import socket
import sys

SOCKET = os.environ.get("HOST_QUERY_SOCKET")

TOOLS = [
    {
        "name": "host_exec",
        "description": (
            "Run one shell command on the host, outside the sandbox. The widest "
            "host tool: use it only when host_journal and host_mount do not fit, "
            "e.g. signing a commit. The user approves every call, so say why it "
            "has to run on the host."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Shell command, e.g. \"git commit -S -m 'fix: thing'\"",
                }
            },
            "required": ["command"],
        },
    },
    {
        "name": "host_mount",
        "description": (
            "Bind a host directory into the sandbox at ~/granted/<name> so the "
            "normal file tools work on it. Read-only unless write is true. "
            "Re-granting a name remounts it."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Absolute host directory"},
                "name": {"type": "string", "description": "Mount name (default: basename)"},
                "write": {"type": "boolean", "description": "Mount read-write"},
            },
            "required": ["path"],
        },
    },
    {
        "name": "host_journal",
        "description": (
            "Read the host's systemd journal. Always use this instead of "
            "journalctl in bash, which silently returns nothing in the sandbox."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "unit": {"type": "string"},
                "lines": {"type": "integer", "description": "Default 100, max 5000"},
                "since": {"type": "string", "description": "e.g. '10 min ago'"},
                "priority": {
                    "type": "string",
                    "enum": ["emerg", "alert", "crit", "err", "warning", "notice", "info", "debug"],
                },
                "boot": {"type": "string", "description": "'0' current, '-1' previous"},
                "grep": {"type": "string"},
                "user_units": {"type": "boolean"},
            },
        },
    },
    {
        "name": "host_ssh_agent",
        "description": (
            "Expose the user's SSH agent inside the sandbox at "
            "~/granted/ssh-agent.sock for the rest of the session. The sandbox "
            "has no SSH identity until then. Call it before ssh, git over ssh, "
            "or remote deploys; the user approves, so say which remote action "
            "needs it."
        ),
        "inputSchema": {"type": "object", "properties": {}},
    },
]

OPS = {
    "host_exec": "exec",
    "host_mount": "mount",
    "host_journal": "journal",
    "host_ssh_agent": "ssh-agent",
}


def call_host(name, args):
    if not SOCKET and os.environ.get("AGENT_JAIL_NO_HOST"):
        raise RuntimeError(
            "Host access is off: another agent started this jail on the host, and host "
            "access belongs to that parent session. Report what you need to the parent."
        )
    if not SOCKET:
        raise RuntimeError(
            "HOST_QUERY_SOCKET is unset: this session is not inside the agent jail. "
            "Run the command directly."
        )
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(35)
            s.connect(SOCKET)
            s.sendall((json.dumps({"op": OPS[name], "args": args}) + "\n").encode())
            data = json.loads(s.makefile("rb").readline())
    except OSError as e:
        raise RuntimeError(f"host-query unreachable: {e}")
    except ValueError:
        raise RuntimeError("host-query sent no valid reply")
    if "error" in data:
        raise RuntimeError(f"host-query error: {data['error']}")

    if name == "host_ssh_agent":
        path = os.path.expanduser(data.get("jail_path", ""))
        return f"SSH agent available. Prefix SSH commands with SSH_AUTH_SOCK={path}"
    if name == "host_mount":
        mode = "read-write" if data.get("mode") == "rw" else "read-only"
        how = "Remounted" if data.get("remounted") else "Mounted"
        return f"{how} {data.get('source')} {mode} at {data.get('jail_path')}"
    code = data.get("exit_code")
    suffix = f" (exit {code})" if code not in (0, None) else ""
    return f"$ {data.get('command', '')}{suffix}\n{data.get('output') or '(no output)'}"


def handle(msg):
    method = msg.get("method")
    params = msg.get("params") or {}
    if method == "initialize":
        return {
            "protocolVersion": params.get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "host", "version": "0.1.0"},
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        name = params.get("name")
        if name not in OPS:
            raise LookupError(f"unknown tool {name!r}")
        try:
            text, err = call_host(name, params.get("arguments") or {}), False
        except RuntimeError as e:
            text, err = str(e), True
        return {"content": [{"type": "text", "text": text}], "isError": err}
    raise LookupError(f"method not found: {method}")


def main():
    for line in sys.stdin:
        if not line.strip():
            continue
        msg = json.loads(line)
        if "id" not in msg:  # notification
            continue
        try:
            reply = {"jsonrpc": "2.0", "id": msg["id"], "result": handle(msg)}
        except LookupError as e:
            reply = {"jsonrpc": "2.0", "id": msg["id"], "error": {"code": -32601, "message": str(e)}}
        sys.stdout.write(json.dumps(reply) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()

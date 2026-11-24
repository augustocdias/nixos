"""Board tools for the user's coding sessions, served by Hermes over loopback.

Cards require an assignee and an existing repository. Dependencies select todo
or ready. Native Hermes roles execute the work; there is no report transport.
"""

import json
import sys
import urllib.error
import urllib.parse
import urllib.request

URL = sys.argv[1].rstrip("/")



BOARD_TOOLS = [
    {
        "name": "board_create",
        "description": (
            "File approved work on the Hermes kanban board with an explicit assignee. "
            "Dependencies select todo or ready; this tool cannot create triage cards. "
            "Fill the header fields from board_template."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "body": {"type": "string", "description": "What to do, or a pointer to the ticket that says it"},
                "repo": {"type": "string", "description": "Absolute path of the one repository this card changes, under ~/dev. Cross-repo work is one card per repository."},
                "tracker": {"type": "string", "description": "Spec and ticket references in the repo's tracker"},
                "git": {"type": "string", "description": "Optional branch=<name> to pin the branch; agents own all Git work"},
                "assignee": {"type": "string", "description": "programmer, reviewer, qa or research"},
                "tenant": {"type": "string", "description": "Groups a spec's cards, e.g. the spec slug"},
                "parents": {"type": "array", "items": {"type": "string"}, "description": "Cards that must finish first"},
            },
            "required": ["title", "body", "repo", "assignee"],
        },
    },
    {
        "name": "board_template",
        "description": "Show the card header template every Hermes card starts with.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "board_list",
        "description": "List cards on the Hermes board, optionally by status or tenant.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "status": {"type": "string", "description": "e.g. triage, ready, running, scheduled, blocked, review, done"},
                "tenant": {"type": "string"},
            },
        },
    },
    {
        "name": "board_show",
        "description": "Show one card and its native Hermes workflow comments.",
        "inputSchema": {
            "type": "object",
            "properties": {"card": {"type": "string"}},
            "required": ["card"],
        },
    },
]


def request(method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        URL + path, data=data, method=method, headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as e:
        raise RuntimeError(json.loads(e.read() or b"{}").get("error", f"HTTP {e.code}"))
    except OSError as e:
        raise RuntimeError(f"Hermes is unreachable at {URL}: {e}")



def call(name, args):
    if name == "board_create":
        reply = request("POST", "/board/create", args)
    elif name == "board_template":
        reply = request("GET", "/board/template")
    elif name == "board_list":
        query = urllib.parse.urlencode({k: v for k, v in args.items() if v})
        reply = request("GET", "/board/list" + (f"?{query}" if query else ""))
    else:
        reply = request("GET", "/board/show?" + urllib.parse.urlencode({"card": args.get("card", "")}))
    return json.dumps(reply, indent=1)


def handle(msg):
    method = msg.get("method")
    params = msg.get("params") or {}
    tools = BOARD_TOOLS
    if method == "initialize":
        return {
            "protocolVersion": params.get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "hermes-board", "version": "1.0.0"},
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": tools}
    if method == "tools/call":
        name = params.get("name")
        if name not in {tool["name"] for tool in tools}:
            raise LookupError(f"unknown tool {name!r}")
        try:
            text, err = call(name, params.get("arguments") or {}), False
        except RuntimeError as e:
            text, err = str(e), True
        return {"content": [{"type": "text", "text": text}], "isError": err}
    raise LookupError(f"method not found: {method}")


def main():
    for line in sys.stdin:
        if not line.strip():
            continue
        msg = json.loads(line)
        if "id" not in msg:
            continue
        try:
            reply = {"jsonrpc": "2.0", "id": msg["id"], "result": handle(msg)}
        except LookupError as e:
            reply = {"jsonrpc": "2.0", "id": msg["id"], "error": {"code": -32601, "message": str(e)}}
        sys.stdout.write(json.dumps(reply) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()

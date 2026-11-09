"""Hermes stdio MCP servers, talking to the plugin's loopback endpoint.

    mcp.py report <url>   report tools for agents launched from a Hermes template
    mcp.py board <url>    board tools for the user's normal Claude Code and omp sessions

Report tools carry the card id and task token from the agent's first message,
plus the harness session id, which the agent never has to know. Board tools
need no credentials: the plugin files every card they create in `triage`.

No dependencies on purpose, like agent-jail/host-mcp.py: initialize /
tools/list / tools/call over newline-delimited JSON.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

MODE, URL = sys.argv[1], sys.argv[2].rstrip("/")


def text_schema(field, description):
    return {
        "type": "object",
        "properties": {
            "card": {"type": "string", "description": "Card id from your first message"},
            "token": {"type": "string", "description": "Task token from your first message"},
            field: {"type": "string", "description": description},
        },
        "required": ["card", "token", field],
    }


REPORT_TOOLS = [
    {
        "name": "report_done",
        "description": "Hand your finished work back to Hermes. Call it every time you finish a task, the first one and every follow-up, even mid-review. It does not close the card: it records your result and wakes the role, which decides the next step (review, another round, done). Without it the card waits forever.",
        "inputSchema": text_schema("result", "What you did and where to find it"),
    },
    {
        "name": "report_blocked",
        "description": "Report that you cannot go on without help, with the reason.",
        "inputSchema": text_schema("reason", "What blocks you and what would unblock you"),
    },
    {
        "name": "ask",
        "description": "Ask your role, the coordinator or the user a question. Wait for the answer as your next input.",
        "inputSchema": text_schema("question", "The question"),
    },
    {
        "name": "comment",
        "description": "Add a progress note to the card. Call it first thing, then whenever useful.",
        "inputSchema": text_schema("text", "The note"),
    },
]
REPORT_FIELDS = {"report_done": "result", "report_blocked": "reason", "ask": "question", "comment": "text"}

BOARD_TOOLS = [
    {
        "name": "board_create",
        "description": (
            "Ask the Hermes coordinator for work: file a card on the Hermes kanban board. "
            "It lands in triage, where the user promotes it; nothing runs until then. "
            "Fill the header fields from board_template; leave a field out when it is not decided."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "body": {"type": "string", "description": "What to do, or a pointer to the ticket that says it"},
                "repo": {"type": "string", "description": "Absolute path of the one repository this card changes, under ~/dev. Cross-repo work is one card per repository."},
                "tracker": {"type": "string", "description": "Spec and ticket references in the repo's tracker"},
                "agents": {"type": "string", "description": "Harness per role, e.g. programmer=claude, reviewer=omp"},
                "git": {"type": "string", "description": "The git-conventions decisions: branch and ownership of branches, worktrees, commits, pushes, PRs"},
                "herdr": {"type": "string", "description": "space=<id>; placement=pane|tab; close=yes|no"},
                "assignee": {"type": "string", "description": "programmer, reviewer, qa or research"},
                "tenant": {"type": "string", "description": "Groups a spec's cards, e.g. the spec slug"},
                "parents": {"type": "array", "items": {"type": "string"}, "description": "Cards that must finish first"},
            },
            "required": ["title", "body"],
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
        "description": "Show one card with its comments, including each agent iteration and session.",
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


def session():
    # Claude Code exports its session id to child processes; `claude --resume` takes it.
    return os.environ.get("CLAUDE_CODE_SESSION_ID", "")


def call(name, args):
    if MODE == "report":
        field = REPORT_FIELDS[name]
        reply = request(
            "POST",
            "/report",
            {
                "card": args.get("card", ""),
                "token": args.get("token", ""),
                "kind": name,
                "text": args.get(field, ""),
                "session_id": session(),
            },
        )
    elif name == "board_create":
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
    tools = REPORT_TOOLS if MODE == "report" else BOARD_TOOLS
    if method == "initialize":
        return {
            "protocolVersion": params.get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": f"hermes-{MODE}", "version": "0.1.0"},
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

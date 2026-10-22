#!/usr/bin/env python3
"""Feed herdr's Agents sidebar with what Claude Code is doing.

Managed by nix (modules/programs/herdr/claude-activity.py). Claude Code port of
omp-activity.ts: one hook script for every event, display-only metadata through
`pane.report_metadata`, never touching the session identity herdr's own hook owns.

Tokens: $agent $title $todo $sub1..$sub3 $submore. No hook carries the session
title or, on resume, the task list, so both are read from the transcript.
"""

import fcntl
import json
import os
import re
import socket
import sys
import time

SOURCE = "user:claude-activity"
SUB_SLOTS = 3
MAX_VALUE = 72
TTL_MS = 12 * 60 * 60 * 1000
TOKENS = ("agent", "title", "todo", "sub1", "sub2", "sub3", "submore")
SUBAGENT_EVENTS = {"SubagentStart", "SubagentStop"}
# apply() result: state changed but no token did.
SAVE = "save"


def clean(value):
    text = " ".join(str(value or "").split())
    return text if len(text) <= MAX_VALUE else text[: MAX_VALUE - 1] + "…"


def field(mapping, *names):
    if not isinstance(mapping, dict):
        return None
    for name in names:
        if mapping.get(name) is not None:
            return mapping[name]
    return None


def fresh():
    return {"model": "", "title": "", "active": False, "tasks": [], "pending": [], "subagents": {}}


def todo_summary(tasks):
    if not tasks:
        return ""
    done = sum(task["status"] == "completed" for task in tasks)
    if done == len(tasks):
        return ""
    active = next((task for task in tasks if task["status"] == "in_progress"), None)
    label = (active.get("active_form") or active.get("subject")) if active else ""
    return clean(f"{done}/{len(tasks)} {label}")


def tokens(state):
    running = list(state["subagents"].values())
    result = {
        "agent": clean(state["model"]) if state["active"] else "",
        "title": clean(state["title"]),
        "todo": todo_summary(state["tasks"]),
        "submore": clean(", ".join(entry["type"] for entry in running[SUB_SLOTS:])),
    }
    for slot in range(SUB_SLOTS):
        entry = running[slot] if slot < len(running) else None
        result[f"sub{slot + 1}"] = (
            clean(f"{entry['type']}: {entry['description']}" if entry["description"] else entry["type"])
            if entry
            else ""
        )
    return result


def task_status(value):
    return value if value in {"pending", "in_progress", "completed"} else "pending"


def apply_tool(state, tool, tool_input, response):
    if tool == "TodoWrite":
        todos = field(tool_input, "todos")
        if isinstance(todos, list):
            state["tasks"] = [
                {
                    "id": str(index),
                    "subject": str(field(todo, "content", "subject") or ""),
                    "active_form": str(field(todo, "activeForm", "active_form") or ""),
                    "status": task_status(field(todo, "status")),
                }
                for index, todo in enumerate(todos)
                if isinstance(todo, dict)
            ]
            return True
    elif tool == "TaskCreate":
        task = field(response, "task")
        task_id = field(task, "id") or field(response, "id", "taskId", "task_id")
        if task_id is None:
            return False
        state["tasks"].append(
            {
                "id": str(task_id),
                "subject": str(field(tool_input, "subject") or field(task, "subject") or ""),
                "active_form": str(field(tool_input, "activeForm", "active_form") or ""),
                "status": "pending",
            }
        )
        return True
    elif tool == "TaskUpdate":
        task_id = field(tool_input, "taskId", "task_id", "id")
        task = next((task for task in state["tasks"] if task["id"] == str(task_id)), None)
        if task is None:
            return False
        status = field(tool_input, "status")
        if status == "deleted":
            state["tasks"].remove(task)
            return True
        if status is not None:
            task["status"] = task_status(status)
        for key, names in (("subject", ("subject",)), ("active_form", ("activeForm", "active_form"))):
            value = field(tool_input, *names)
            if value is not None:
                task[key] = str(value)
        return True
    return False


TITLE_TAIL = 1 << 20


def title_from(lines):
    title = None
    for line in lines:
        if '"ai-title"' not in line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("type") == "ai-title" and isinstance(entry.get("aiTitle"), str):
            title = entry["aiTitle"]
    return title


def latest_title(transcript):
    # Claude rewrites its ai-title entry every few turns, so the tail of a
    # multi-megabyte transcript is enough.
    try:
        with open(transcript, "rb") as handle:
            handle.seek(max(0, os.fstat(handle.fileno()).st_size - TITLE_TAIL))
            return title_from(handle.read().decode("utf-8", "replace").splitlines())
    except (OSError, TypeError):
        return None


def replay(state, transcript):
    """Rebuild the task list and title of a resumed session from its transcript."""
    calls = {}
    try:
        with open(transcript, encoding="utf-8", errors="replace") as handle:
            lines = list(handle)
    except (OSError, TypeError):
        return
    title = title_from(lines)
    if title is not None:
        state["title"] = title
    for line in lines:
        if not any(name in line for name in ('"TaskCreate"', '"TaskUpdate"', '"TodoWrite"', '"tool_result"')):
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("isSidechain"):
            continue
        content = (entry.get("message") or {}).get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use" and block.get("name") in {"TaskCreate", "TaskUpdate", "TodoWrite"}:
                calls[block.get("id")] = (block["name"], block.get("input"))
            elif block.get("type") == "tool_result" and block.get("tool_use_id") in calls:
                name, tool_input = calls.pop(block["tool_use_id"])
                if not block.get("is_error"):
                    apply_tool(state, name, tool_input, entry.get("toolUseResult"))


def apply(state, event):
    name = event.get("hook_event_name")
    if name == "SessionStart":
        # Compaction keeps the session and its task list.
        if event.get("source") != "compact":
            state.clear()
            state.update(fresh())
            if event.get("source") in {"resume", "fork"}:
                replay(state, event.get("transcript_path"))
        model = field(event, "model")
        if isinstance(model, dict):
            model = field(model, "id", "display_name")
        if model:
            state["model"] = str(model)
    elif name == "UserPromptSubmit":
        state["active"] = True
    # Stop does not fire on an interrupt; the idle prompt notification does, a minute later.
    elif name == "Stop" or (name == "Notification" and event.get("notification_type") == "idle_prompt"):
        if not state["active"]:
            return False
        state["active"] = False
    elif name == "PreToolUse" and event.get("tool_name") in {"Agent", "Task"}:
        tool_input = event.get("tool_input") or {}
        state["pending"].append(
            {
                "type": clean(field(tool_input, "subagent_type") or "general-purpose"),
                "description": clean(field(tool_input, "description") or ""),
            }
        )
        del state["pending"][:-16]
        return SAVE
    elif name == "PostToolUse":
        return apply_tool(state, event.get("tool_name"), event.get("tool_input"), event.get("tool_response"))
    elif name == "SubagentStart":
        agent_type = clean(event.get("agent_type") or "")
        index = next((i for i, entry in enumerate(state["pending"]) if entry["type"] == agent_type), None)
        entry = state["pending"].pop(index) if index is not None else {"type": agent_type or "agent", "description": ""}
        state["subagents"][str(event.get("agent_id"))] = entry
    elif name == "SubagentStop":
        if state["subagents"].pop(str(event.get("agent_id")), None) is None:
            return False
    elif name == "SessionEnd":
        state.clear()
        state.update(fresh())
    else:
        return False
    return True


def publish(state, pane_id, socket_path):
    request = {
        "id": f"{SOURCE}:{int(time.time() * 1000)}:{os.getpid()}",
        "method": "pane.report_metadata",
        "params": {
            "pane_id": pane_id,
            "source": SOURCE,
            "seq": time.time_ns(),
            "tokens": tokens(state),
            "ttl_ms": TTL_MS,
        },
    }
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(0.5)
        client.connect(socket_path)
        client.sendall((json.dumps(request) + "\n").encode())
        try:
            client.recv(4096)
        except OSError:
            pass


def main():
    pane_id = os.environ.get("HERDR_PANE_ID")
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    if os.environ.get("HERDR_ENV") != "1" or not pane_id or not socket_path:
        return
    event = json.load(sys.stdin)
    if not isinstance(event, dict):
        return
    # Hooks fired inside a subagent carry agent_id; only its lifecycle belongs to the pane.
    if event.get("agent_id") and event.get("hook_event_name") not in SUBAGENT_EVENTS:
        return
    session_id = str(event.get("session_id") or "")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", session_id):
        return

    state_dir = os.path.join(
        os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude"), "herdr-activity"
    )
    os.makedirs(state_dir, exist_ok=True)
    path = os.path.join(state_dir, session_id + ".json")
    # Parallel tool calls fire their hooks concurrently; the lock serializes read-modify-publish.
    with open(path, "a+", encoding="utf-8") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.seek(0)
        try:
            state = {**fresh(), **json.loads(handle.read())}
        except ValueError:
            state = fresh()
        outcome = apply(state, event)
        if outcome is True and event.get("hook_event_name") not in {"SessionStart", "SessionEnd"}:
            title = latest_title(event.get("transcript_path"))
            if title is not None:
                state["title"] = title
        if not outcome:
            return
        if event.get("hook_event_name") == "SessionEnd":
            os.unlink(path)
        else:
            handle.seek(0)
            handle.truncate()
            json.dump(state, handle)
            handle.flush()
        if outcome is not SAVE:
            publish(state, pane_id, socket_path)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass

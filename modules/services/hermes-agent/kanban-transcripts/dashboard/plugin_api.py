"""Kanban transcripts backend, mounted at /api/plugins/kanban-transcripts/.

A worker run's session id is the ``owner_admitted`` task event the owner gateway writes when it
admits the run (gateway/session_kanban.py). The session lives in the run profile's state.db, not
the profile Desktop shows. Every read is read-only: the board DBs open with ``mode=ro`` and the
session store through ``SessionDB(read_only=True)``, so a transcript never resumes or writes a
session. The HTML is the same pipeline as
``hermes -p <profile> sessions export <file> --format html --session-id <id> --redact``.
"""

from __future__ import annotations

import base64
import json
import re
import sqlite3
from contextlib import closing
from pathlib import Path

from fastapi import APIRouter, HTTPException

router = APIRouter()


def _boards():
    from hermes_cli.kanban_db_boards import list_boards

    for meta in list_boards(include_archived=False):
        path = Path(meta["db_path"])
        if path.is_file():
            yield path


def _read(path: Path):
    conn = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return closing(conn)


def _runs(task_id: str) -> list[dict]:
    """The card's runs, newest first, each with its profile and worker session id (or None)."""
    for path in _boards():
        with _read(path) as conn:
            rows = conn.execute(
                "SELECT r.id, COALESCE(r.profile, t.assignee) AS profile, r.status, r.outcome,"
                " r.started_at, r.ended_at,"
                " (SELECT e.payload FROM task_events e WHERE e.task_id = r.task_id AND e.run_id = r.id"
                "  AND e.kind = 'owner_admitted' ORDER BY e.id DESC LIMIT 1) AS receipt"
                " FROM task_runs r JOIN tasks t ON t.id = r.task_id WHERE r.task_id = ?"
                " ORDER BY r.started_at DESC, r.id DESC",
                (task_id,),
            ).fetchall()
        if rows:
            return [
                {**{k: row[k] for k in row.keys() if k != "receipt"},
                 "session_id": json.loads(row["receipt"]).get("session_id") if row["receipt"] else None}
                for row in rows
            ]
    return []


@router.get("/lookup")
def lookup(short: str, title: str = ""):
    """The card the open task modal shows, with its runs.

    The modal's header shows only ``shortId`` (the first six hex digits of the id) and the title,
    so a prefix shared by several cards is narrowed by the title, which is the id when blank.
    """
    if not re.fullmatch(r"[0-9a-f]{1,8}", short):
        raise HTTPException(status_code=400, detail="short must be hex")
    found = []
    for path in _boards():
        with _read(path) as conn:
            found += conn.execute("SELECT id, title FROM tasks WHERE id LIKE ?", (f"t_{short}%",)).fetchall()
    if len(found) > 1:
        found = [row for row in found if (row["title"] or row["id"]).strip() == title.strip()]
    if len(found) != 1:
        raise HTTPException(status_code=404, detail=f"{len(found)} cards match t_{short}")
    task_id = found[0]["id"]
    return {"task_id": task_id, "runs": _runs(task_id)}


@router.get("/tasks/{task_id}/runs/{run_id}/html")
def html(task_id: str, run_id: int):
    """One run's transcript as a ``data:`` URL for the SDK's SandboxedFrame."""
    # Profile and session come from the board, never from the client.
    run = next((r for r in _runs(task_id) if r["id"] == run_id), None)
    if run is None or not run["session_id"] or not run["profile"]:
        raise HTTPException(status_code=404, detail="run has no worker session")

    from hermes_cli.profiles import resolve_profile_env
    from hermes_cli.session_export import export_projection
    from hermes_cli.session_export_html import generate_html_export
    from hermes_cli.session_export_md import redact_session_data
    from hermes_state import SessionDB

    try:
        db = SessionDB(Path(resolve_profile_env(run["profile"])) / "state.db", read_only=True)
    except Exception as exc:
        raise HTTPException(status_code=404, detail=f"session store for {run['profile']!r} unavailable: {exc}")
    try:
        data = db.export_session(run["session_id"], **export_projection(True))
    finally:
        db.close()
    if not data:
        raise HTTPException(status_code=404, detail=f"session {run['session_id']} not found")
    page = generate_html_export(redact_session_data(data)).encode("utf-8")
    # shortcut: Chromium caps URLs at 2 MB, so a very long transcript may not render; serve an http URL if that bites.
    return {"src": "data:text/html;charset=utf-8;base64," + base64.b64encode(page).decode("ascii")}

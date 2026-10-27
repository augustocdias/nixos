#!/usr/bin/env python3
"""Upsert the Nix-declared tools into Open WebUI's `tool` table.

Open WebUI stores tools as database rows, not files, so they have to be pushed
in over the HTTP API. `create` refuses an existing id and `update` refuses a
missing one, so the id decides which call to make. Only ids named in the
manifest are ever touched.
"""

import base64
import hashlib
import hmac
import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = os.environ["OWUI_BASE_URL"]
DB_PATH = os.environ["OWUI_DB"]
SECRET_FILE = os.environ["OWUI_SECRET_FILE"]
MANIFEST = os.environ["OWUI_TOOL_MANIFEST"]


def log(msg):
    print(f"[import-tools] {msg}", flush=True)


def wait_for_file(path, tries=60, delay=2):
    for _ in range(tries):
        try:
            if os.path.getsize(path) > 0:
                return True
        except OSError:
            pass
        time.sleep(delay)
    return False


def wait_for_http(url, tries=150, delay=2):
    for _ in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=5) as resp:
                if resp.status == 200:
                    return True
        except Exception:
            pass
        time.sleep(delay)
    return False


def b64url(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def mint_token(secret, user_id, session_stamp):
    """Sign a session token bound to the account's current revocation stamp."""
    header = b64url(
        json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode()
    )
    payload = b64url(
        json.dumps(
            {
                "id": user_id,
                "session_stamp": session_stamp,
                "jti": str(uuid.uuid4()),
                "iat": int(time.time()),
            },
            separators=(",", ":"),
        ).encode()
    )
    signed = header + b"." + payload
    signature = b64url(hmac.new(secret.encode(), signed, hashlib.sha256).digest())
    return (signed + b"." + signature).decode()


def owner_auth(db_path):
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        return con.execute(
            "SELECT u.id, a.session_stamp FROM user u JOIN auth a ON a.id = u.id "
            "WHERE u.role = 'admin' AND a.active = 1 ORDER BY u.created_at LIMIT 1"
        ).fetchone()
    finally:
        con.close()


def api(method, path, token, payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(BASE + path, data=body, method=method)
    request.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=120) as resp:
        text = resp.read().decode()
    return json.loads(text) if text else None


def main():
    if not wait_for_file(SECRET_FILE):
        log(f"secret never appeared at {SECRET_FILE}")
        return 1
    with open(SECRET_FILE, encoding="utf-8") as handle:
        secret = handle.read().strip()

    if not wait_for_http(f"{BASE}/health"):
        log("open-webui never became healthy")
        return 1

    if not wait_for_file(DB_PATH):
        log(f"database never appeared at {DB_PATH}")
        return 1

    owner = owner_auth(DB_PATH)
    if owner is None:
        log("no active administrator credential exists")
        return 1

    token = mint_token(secret, *owner)

    with open(MANIFEST, encoding="utf-8") as handle:
        manifest = json.load(handle)

    try:
        installed = {tool["id"] for tool in (api("GET", "/api/v1/tools/", token) or [])}
    except urllib.error.HTTPError as err:
        log(f"could not list tools: {err.code} {err.read().decode()[:200]}")
        return 1

    failures = 0
    for tool_id, spec in sorted(manifest.items()):
        with open(spec["path"], encoding="utf-8") as handle:
            content = handle.read()

        exists = tool_id in installed
        route = (
            f"/api/v1/tools/id/{tool_id}/update" if exists else "/api/v1/tools/create"
        )
        payload = {
            "id": tool_id,
            "name": spec["name"],
            "content": content,
            "meta": {},
        }

        try:
            api("POST", route, token, payload)
            log(f"{'updated' if exists else 'created'} {tool_id}")
        except urllib.error.HTTPError as err:
            log(f"FAILED {tool_id}: {err.code} {err.read().decode()[:300]}")
            failures += 1

    log(f"done, {len(manifest) - failures}/{len(manifest)} tools in place")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

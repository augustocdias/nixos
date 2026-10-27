"""Fail-closed Honcho readiness and stable workspace-key provisioning."""

import argparse
import math
import os
import time
from pathlib import Path

import httpx
import psycopg


def database_ready():
    with (
        psycopg.connect(
            dbname="honcho", user="honcho", host=os.environ["PGHOST"], connect_timeout=5
        ) as connection,
        connection.cursor() as cursor,
    ):
        cursor.execute("SELECT current_setting('server_encoding') = 'UTF8'")
        if cursor.fetchone() != (True,):
            raise RuntimeError(
                "Honcho database must use UTF8; migrate the existing database before startup"
            )
        cursor.execute("SELECT extname FROM pg_extension")
        if not {"vector", "pg_trgm", "btree_gin"} <= {row[0] for row in cursor}:
            raise RuntimeError("Required PostgreSQL extensions are missing")
        cursor.execute(
            "SELECT rolsuper, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname = current_user"
        )
        if cursor.fetchone() != (False, False, False):
            raise RuntimeError("Honcho database role has unexpected privileges")


def wait_database():
    for attempt in range(60):
        try:
            database_ready()
            return
        except (psycopg.Error, RuntimeError):
            if attempt == 59:
                raise
            time.sleep(2)


def verify_embeddings():
    with httpx.Client(timeout=120, trust_env=False) as client:
        response = client.post(
            "http://127.0.0.1:11434/v1/embeddings",
            json={
                "model": "qwen3-embedding:0.6b",
                "input": "Local embedding readiness",
                "encoding_format": "float",
            },
        )
        response.raise_for_status()
        vector = response.json()["data"][0]["embedding"]
        if len(vector) != 1024 or not all(
            type(v) in (int, float) and math.isfinite(v) for v in vector
        ):
            raise RuntimeError("Embedding endpoint must return 1024 finite numbers")


def provision():
    from src.security import create_admin_jwt

    wait_database()
    root = Path(os.environ["HONCHO_KEYS_DIR"])
    with httpx.Client(
        base_url="http://127.0.0.1:8001", timeout=10, trust_env=False
    ) as client:
        for attempt in range(60):
            try:
                client.get("/health").raise_for_status()
                break
            except httpx.HTTPError:
                if attempt == 59:
                    raise
                time.sleep(2)
        admin = {"Authorization": f"Bearer {create_admin_jwt()}"}
        keys = {}
        for person in ("augusto", "livia"):
            workspace = f"hermes-{person}"
            response = client.post(
                "/v3/workspaces", json={"name": workspace}, headers=admin
            )
            response.raise_for_status()
            path = root / person
            if path.exists():
                key = path.read_text().strip()
            else:
                response = client.post(
                    "/v3/keys", params={"workspace_id": workspace}, headers=admin
                )
                response.raise_for_status()
                key = response.json()["key"]
                # Exclusive creation retains a stable scoped key across restarts.
                with open(
                    path, "x", opener=lambda p, flags: os.open(p, flags, 0o600)
                ) as handle:
                    handle.write(key + "\n")
            response = client.post(
                "/v3/workspaces",
                json={"name": workspace},
                headers={"Authorization": f"Bearer {key}"},
            )
            response.raise_for_status()
            keys[person] = key
        for person, key in keys.items():
            other = "livia" if person == "augusto" else "augusto"
            response = client.post(
                "/v3/workspaces",
                json={"name": f"hermes-{other}"},
                headers={"Authorization": f"Bearer {key}"},
            )
            if response.status_code not in (401, 403):
                raise RuntimeError("Honcho workspace key isolation failed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("prepare", "provision"))
    action = parser.parse_args().action
    if action == "prepare":
        wait_database()
        verify_embeddings()
    else:
        provision()

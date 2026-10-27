"""Migrate existing WebUI identities before opening the authenticated LAN listener."""

import asyncio
import json
import os
import socket
import sqlite3
from contextlib import closing
from pathlib import Path

AUGUSTO_ID = "c6536b76-6232-416e-97c7-7d75b38133d8"


def save_state(path, state):
    temporary = path.with_name(f".{path.name}.{os.getpid()}")
    with open(
        temporary, "x", opener=lambda p, flags: os.open(p, flags, 0o600)
    ) as handle:
        json.dump(state, handle)
    temporary.replace(path)


async def migrate_accounts(passwords, state_path):
    from open_webui.internal.db import get_async_db
    from open_webui.models.auths import Auth, Auths
    from open_webui.models.models import ModelForm, Models
    from open_webui.models.users import User, Users
    from open_webui.utils.auth import get_password_hash, verify_password
    from sqlalchemy import func, select

    identities = {}
    async with get_async_db() as db:
        for table in (User, Auth):
            rows = (
                await db.execute(
                    select(table.id, func.lower(table.email)).where(
                        func.lower(table.email).in_(
                            ("admin@localhost", "augusto@localhost", "livia@localhost")
                        )
                    )
                )
            ).all()
            emails = [email for _, email in rows]
            if len(set(emails)) != len(emails):
                raise RuntimeError("Duplicate WebUI login identity")
            if any(
                email != "livia@localhost" and identity != AUGUSTO_ID
                for identity, email in rows
            ):
                raise RuntimeError("Conflicting Augusto login identity")
            identities[table.__tablename__] = {
                identity for identity, email in rows if email == "livia@localhost"
            }
    if identities["user"] != identities["auth"]:
        raise RuntimeError("Livia auth/user identity mismatch")

    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    augusto = await Users.get_user_by_id(AUGUSTO_ID)
    auth = await Auths.get_auth_by_id(AUGUSTO_ID)
    if (
        not augusto
        or not auth
        or augusto.email not in ("admin@localhost", "augusto@localhost")
    ):
        raise RuntimeError(
            "Existing Augusto identity is missing or unexpected; refusing account replacement"
        )
    if auth.email not in ("admin@localhost", "augusto@localhost"):
        raise RuntimeError("Unexpected Augusto credential identity")
    users = {}
    for person, role in (("augusto", "admin"), ("livia", "user")):
        email = f"{person}@localhost"
        user = await Users.get_user_by_email(email)
        if person == "augusto":
            if user and user.id != AUGUSTO_ID:
                raise RuntimeError("Conflicting Augusto email identity")
            user = augusto
        elif user and person not in state:
            # Resume an interrupted create only when it still has the initial credential.
            credential = await Auths.get_auth_by_id(user.id)
            if (
                user.name != person
                or user.role != role
                or not credential
                or not await verify_password(passwords[person], credential.password)
            ):
                raise RuntimeError("Conflicting Livia identity")
        if person in state and (not user or state[person] != user.id):
            raise RuntimeError("Bootstrap identity journal conflicts with database")
        if not user:
            user = await Auths.insert_new_auth(
                email, await get_password_hash(passwords[person]), person, role=role
            )
            if not user:
                raise RuntimeError("Could not create Livia account")
        elif person not in state:
            if not await Auths.update_user_password_by_id(
                user.id, await get_password_hash(passwords[person])
            ):
                raise RuntimeError("Could not initialize account password")
            async with get_async_db() as db:
                await Auths.revoke_sessions_by_user_id(user.id, db=db)
                await db.commit()
        if not await Auths.update_email_by_id(user.id, email):
            raise RuntimeError("Could not synchronize account email")
        user = await Users.update_user_by_id(
            user.id, {"name": person, "email": email, "role": role}
        )
        if not user:
            raise RuntimeError("Could not update account identity")
        state[person] = user.id
        save_state(state_path, state)
        users[person] = user

    for person, user in users.items():
        model_id = f"{person}.hermes-agent"
        existing = await Models.get_model_by_id(model_id)
        if existing and existing.user_id != user.id:
            raise RuntimeError("Conflicting Hermes model owner")
        form = ModelForm(
            id=model_id,
            name=f"Hermes — {person}",
            base_model_id=None,
            params=existing.params if existing else {},
            meta=existing.meta if existing else {},
            access_grants=[],
            is_active=True,
        )
        result = (
            await Models.update_model_by_id(model_id, form)
            if existing
            else await Models.insert_new_model(form, user.id)
        )
        if not result or result.user_id != user.id or result.access_grants:
            raise RuntimeError("Could not enforce private profile model")


def main():
    os.umask(0o077)
    passwords = {}
    for person in ("augusto", "livia"):
        value = (
            Path(os.environ[f"OWUI_{person.upper()}_PASSWORD_FILE"]).read_text().strip()
        )
        if len(value) < 20:
            raise RuntimeError(
                "Initial WebUI password must contain at least 20 characters"
            )
        passwords[person] = value
    if passwords["augusto"] == passwords["livia"]:
        raise RuntimeError("WebUI accounts require different initial passwords")
    try:
        connection = socket.create_connection(("127.0.0.1", 8080), timeout=2)
    except ConnectionRefusedError:
        pass
    else:
        connection.close()
        raise RuntimeError("Stop the old WebUI listener before migrating accounts")
    data = Path(os.environ["DATA_DIR"])
    database = data / "webui.db"
    if not database.is_file():
        raise RuntimeError(
            "Existing WebUI database is missing; refusing to replace user history"
        )
    backup = data / "webui.db.pre-hermes.bak"
    if not backup.exists():
        temporary_backup = backup.with_name(f".{backup.name}.{os.getpid()}")
        with (
            closing(sqlite3.connect(f"file:{database}?mode=ro", uri=True)) as source,
            closing(sqlite3.connect(temporary_backup)) as target,
        ):
            source.backup(target)
        temporary_backup.replace(backup)
    # Use the packaged migration path, but run it explicitly after the backup.
    os.environ["ENABLE_DB_MIGRATIONS"] = "False"
    from open_webui.config import run_migrations
    from open_webui.internal.db import async_engine

    run_migrations()

    async def initialize():
        try:
            await migrate_accounts(passwords, data / "hermes-bootstrap.json")
        finally:
            await async_engine.dispose()

    asyncio.run(initialize())


if __name__ == "__main__":
    main()

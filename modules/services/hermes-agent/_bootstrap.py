"""Create native profiles without cloning, then render runtime-only credentials."""

import json
import os
import sys
import tempfile
import time
from pathlib import Path

import httpx
from dotenv import dotenv_values, set_key, unset_key
from hermes_cli.config import require_readable_config_before_write
from hermes_cli.profiles import create_profile, profile_exists


def read_secret(path):
    for attempt in range(60):
        try:
            value = Path(path).read_text().strip()
            if not value:
                raise ValueError("Empty service credential")
            return value
        except FileNotFoundError:
            if attempt == 59:
                raise
            time.sleep(2)


def atomic_write(path, text):
    temporary = path.with_name(f".{path.name}.{os.getpid()}")
    with open(
        temporary, "x", opener=lambda p, flags: os.open(p, flags, 0o600)
    ) as handle:
        handle.write(text)
    temporary.replace(path)


def merge_config(existing, managed):
    result = existing.copy()
    for key, value in managed.items():
        if isinstance(value, dict):
            previous = result.get(key)
            result[key] = merge_config(
                previous if isinstance(previous, dict) else {}, value
            )
        else:
            result[key] = value
    return result


def write_config(path, managed):
    existing = require_readable_config_before_write(path)
    atomic_write(path, json.dumps(merge_config(existing, managed)))


def write_env(path, managed):
    with tempfile.TemporaryDirectory(dir=path.parent) as directory:
        temporary = Path(directory) / ".env"
        atomic_write(temporary, path.read_text() if path.exists() else "")
        # Listener ownership stays declarative; channel tokens and allowlists stay local.
        for key in dotenv_values(temporary, interpolate=False):
            if key.startswith("API_SERVER_"):
                unset_key(temporary, key)
        for key, value in managed.items():
            set_key(temporary, key, value)
        temporary.replace(path)


def bootstrap(manifest):
    root = Path(os.environ["HERMES_HOME"])
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    host_key = read_secret(manifest["host_key"])
    if len(host_key) < 16:
        raise ValueError("Host API key must contain at least 16 characters")
    keys = {
        person: read_secret(path) for person, path in manifest["profile_keys"].items()
    }
    if len({host_key, *keys.values()}) != 3 or any(
        len(key) < 16 for key in keys.values()
    ):
        raise ValueError(
            "Host and personal API keys must be distinct and at least 16 characters"
        )
    mcp_env = {
        name: read_secret(path) for name, path in manifest["mcp_secrets"].items()
    }
    write_config(root / "config.yaml", manifest["host_config"])
    write_env(
        root / ".env",
        {
            "API_SERVER_ENABLED": "true",
            "API_SERVER_HOST": "127.0.0.1",
            "API_SERVER_PORT": "8650",
            "API_SERVER_MODEL_NAME": "hermes-agent",
            "API_SERVER_KEY": host_key,
            "OPENAI_API_KEY": "ollama",
        },
    )
    for person in ("augusto", "livia"):
        if not profile_exists(person):
            create_profile(person, no_alias=True)
        home = root / "profiles" / person
        if home.is_symlink():
            raise RuntimeError(
                "Personal profile home must not be shared through a symlink"
            )
        key = keys[person]
        honcho_key = read_secret(Path(manifest["honcho_keys"]) / person)
        with httpx.Client(timeout=10, trust_env=False) as client:
            for attempt in range(60):
                try:
                    response = client.post(
                        "http://127.0.0.1:8001/v3/workspaces",
                        json={"name": f"hermes-{person}"},
                        headers={"Authorization": f"Bearer {honcho_key}"},
                    )
                    response.raise_for_status()
                    other = "livia" if person == "augusto" else "augusto"
                    denied = client.post(
                        "http://127.0.0.1:8001/v3/workspaces",
                        json={"name": f"hermes-{other}"},
                        headers={"Authorization": f"Bearer {honcho_key}"},
                    )
                    if denied.status_code not in (401, 403):
                        raise RuntimeError("Honcho key must be scoped to one workspace")
                    break
                except httpx.HTTPError:
                    if attempt == 59:
                        raise
                    time.sleep(2)
        write_config(home / "config.yaml", manifest["profile_config"])
        write_env(
            home / ".env",
            {
                "API_SERVER_KEY": key,
                "API_SERVER_MODEL_NAME": "hermes-agent",
                "OPENAI_API_KEY": "ollama",
                **mcp_env,
            },
        )
        atomic_write(home / "SOUL.md", Path(manifest["soul"]).read_text())
        honcho = dict(
            manifest["honcho_config"],
            workspace=f"hermes-{person}",
            aiPeer=f"hermes-{person}",
            peerName=person,
            apiKey=honcho_key,
        )
        atomic_write(home / "honcho.json", json.dumps(honcho))
        for directory in ("plugins", "memories", "sessions", "skills", "cron"):
            (home / directory).mkdir(exist_ok=True)
        for name in ("MEMORY.md", "USER.md"):
            path = home / "memories" / name
            if not path.exists():
                path.touch(mode=0o600)
        plugin = home / "plugins" / "honcho"
        target = Path(manifest["plugin"])
        if plugin.is_symlink():
            if plugin.resolve() != target:
                plugin.unlink()
                plugin.symlink_to(target)
        elif plugin.exists():
            raise RuntimeError(
                "Refusing to replace an unmanaged Honcho plugin directory"
            )
        else:
            plugin.symlink_to(target)


if __name__ == "__main__":
    os.umask(0o077)
    bootstrap(json.loads(Path(sys.argv[1]).read_text()))

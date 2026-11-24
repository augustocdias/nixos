"""Helpers the profile bootstrap (_bootstrap_work.py) uses to write Hermes homes."""

import os
import tempfile
import time
from pathlib import Path

from dotenv import dotenv_values, set_key, unset_key


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


def link_plugin(plugin, target):
    if plugin.is_symlink():
        if plugin.resolve() != target:
            plugin.unlink()
            plugin.symlink_to(target)
    elif plugin.exists():
        raise RuntimeError(
            f"Refusing to replace an unmanaged directory: {plugin}"
        )
    else:
        plugin.symlink_to(target)

"""Create the laptop's Hermes profiles and merge the Nix-owned settings into them.

Shares its helpers with the macmini bootstrap (_bootstrap.py). Runtime setup
(model login, chat platforms, routes, Google) keeps every key Nix does not own,
and a malformed config.yaml stops startup instead of being overwritten.
"""

import json
import os
import sys
from pathlib import Path

from _bootstrap import atomic_write, enable_plugins, link_plugin, write_config
from hermes_cli.profiles import create_profile, profile_exists, write_profile_meta


def seed(home, managed, plugin, skins):
    write_config(home / "config.yaml", managed["config"])
    atomic_write(home / "SOUL.md", Path(managed["soul"]).read_text())
    for directory in ("plugins", "memories", "sessions", "skills", "cron", "skins"):
        (home / directory).mkdir(exist_ok=True)
    for name in ("MEMORY.md", "USER.md"):
        path = home / "memories" / name
        if not path.exists():
            path.touch(mode=0o600)
    for name, target in skins.items():
        link_plugin(home / "skins" / f"{name}.yaml", Path(target))
    if managed["plugin"]:
        link_plugin(home / "plugins" / "herdr-agents", Path(plugin))
        enable_plugins(home / "config.yaml", ["herdr-agents"])


def bootstrap(manifest):
    root = Path(os.environ["HERMES_HOME"])
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    seed(root, manifest["root"], manifest["plugin"], manifest["skins"])
    for name, managed in manifest["profiles"].items():
        if not profile_exists(name):
            create_profile(name, no_alias=True)
        home = root / "profiles" / name
        if home.is_symlink():
            raise RuntimeError(f"Profile home must not be a symlink: {home}")
        seed(home, managed, manifest["plugin"], manifest["skins"])
        # The triage decomposer routes cards to profiles by this description.
        write_profile_meta(home, description=managed["description"], description_auto=False)


if __name__ == "__main__":
    os.umask(0o077)
    bootstrap(json.loads(Path(sys.argv[1]).read_text()))

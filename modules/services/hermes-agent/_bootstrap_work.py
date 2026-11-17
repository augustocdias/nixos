"""Create the work profiles and merge the Nix-owned settings into them.

Shares helpers with the macmini household bootstrap (_bootstrap.py). Runtime setup
(model login, chat platforms, routes, Google) keeps every key Nix does not own,
and a malformed config.yaml stops startup instead of being overwritten.
"""

import fcntl
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from _bootstrap import atomic_write, link_plugin, merge_config, read_secret, write_env
from hermes_cli.config import require_readable_config_before_write
from hermes_cli.profiles import create_profile, profile_exists, write_profile_meta
from hermes_cli.plugins_cmd_git import _update_install_record
from hermes_constants import reset_hermes_home_override, set_hermes_home_override


def seed(home, managed, plugin, skins, provider):
    path = home / "config.yaml"
    config = merge_config(require_readable_config_before_write(path), managed["config"])
    config["model"] = managed["config"]["model"]
    config.setdefault("auxiliary", {}).update(managed["config"].get("auxiliary", {}))
    # These keys belonged to the removed external-agent workflow.
    config.get("mcp_servers", {}).pop("host", None)
    for name in ("linear", "notion", "datadog"):
        server = config.get("mcp_servers", {}).get(name, {})
        for key in ("tool_costs", "spend_limit", "cost_unit"):
            server.pop(key, None)
    entries = config.get("plugins", {}).get("entries", {})
    entries.pop("herdr-agents", None)
    legacy = home / "plugins" / "herdr-agents"
    if legacy.is_symlink():
        legacy.unlink()
    config.pop("fallback_model", None)
    Path(managed["config"]["terminal"]["cwd"]).mkdir(parents=True, exist_ok=True)
    atomic_write(path, json.dumps(config))
    environment = {**managed.get("env", {}), **{
        key: read_secret(path) for key, path in managed.get("secrets", {}).items()
    }}
    if environment:
        write_env(home / ".env", environment)
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
        link_plugin(home / "plugins" / "hermes-workflow", Path(plugin))
    if provider is not None:
        link_plugin(home / "plugins" / "claude-subscription-directsdk", provider)
    if "hwiki" in managed:
        hwiki = home / "hwiki.json"
        local = json.loads(hwiki.read_text()) if hwiki.exists() else {}
        atomic_write(hwiki, json.dumps({**local, **managed["hwiki"]}))
    for name, source in managed.get("scripts", {}).items():
        # Cron runs only scripts that resolve inside scripts/, so a store symlink would be refused.
        (home / "scripts").mkdir(exist_ok=True)
        atomic_write(home / "scripts" / name, Path(source).read_text())
    if managed.get("cron"):
        schedule(home, managed["cron"])


def schedule(home, jobs):
    """Create the Nix-owned cron jobs by name and update them only when Nix changed them."""
    from cron.jobs import create_job, list_jobs, parse_schedule, update_job, use_cron_store

    with use_cron_store(home):
        existing = {job.get("name"): job for job in list_jobs(include_disabled=True)}
        for job in jobs:
            current = existing.get(job["name"])
            if current is None:
                create_job(**job)
                continue
            wanted = {key: job[key] for key in ("prompt", "skills", "deliver", "script") if key in job}
            if parse_schedule(job["schedule"]).get("display", job["schedule"]) != current.get("schedule_display"):
                wanted["schedule"] = job["schedule"]
            changed = {key: value for key, value in wanted.items() if current.get(key) != value}
            if changed:
                update_job(current["id"], changed)


def bootstrap(manifest):
    root = Path(os.environ["HERMES_HOME"])
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    provider = None
    if manifest.get("provider"):
        source = Path(manifest["provider"])
        provider = root / "nix" / "providers" / source.parent.name / source.name
        if not provider.exists():
            # Hermes stages providers with copytree; read-only store directory modes break staging.
            provider.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(dir=provider.parent) as directory:
                staged = Path(directory) / source.name
                shutil.copytree(source, staged)
                for directory, _, _ in os.walk(staged):
                    Path(directory).chmod(0o700)
                staged.rename(provider)
    seed(root, manifest["root"], manifest["plugin"], manifest["skins"], provider)
    for name, managed in manifest["profiles"].items():
        home = root / "profiles" / name
        if home.is_symlink():
            raise RuntimeError(f"Profile home must not be a symlink: {home}")
        if not profile_exists(name):
            if home.exists():
                # Home Manager installs plugin and avatar links before the first profile bootstrap.
                plugins = home / "plugins"
                linked = [plugins, *([home / "assets"] if (home / "assets").exists() else [])]
                if set(p.name for p in home.iterdir()) - {"plugins", "assets"} or not plugins.is_dir() or not all(
                    directory.is_dir() and not directory.is_symlink() and all(
                        p.is_symlink() and str(p.resolve()).startswith("/nix/store/") for p in directory.iterdir()
                    )
                    for directory in linked
                ):
                    raise RuntimeError(f"Refusing to adopt an unmanaged profile directory: {home}")
                write_profile_meta(home, description=managed["description"], description_auto=False)
            else:
                create_profile(name, no_alias=True)
        seed(home, managed, manifest["plugin"], manifest["skins"], provider)
        # The triage decomposer routes cards to profiles by this description.
        write_profile_meta(home, description=managed["description"], description_auto=False)
    office = manifest["office"]
    repo = "https://github.com/oslook/hermes-desktop-plugin-office-3d"
    revision = office["revision"]
    for home in [root, *(root / "profiles" / name for name in office["profiles"])]:
        plugin = home / "plugins" / "office-3d"
        if not plugin.is_symlink() or plugin.resolve() != Path(office["source"]):
            raise RuntimeError(f"Office catalog registration requires its Nix-managed link: {plugin}")
        token = set_hermes_home_override(home)
        try:
            # The catalog matches installer-owned identity, not the plugin's manifest name.
            _update_install_record("office-3d", lambda current: {
                **(current or {}),
                "source": repo,
                "revision": revision,
                "pinned": True,
                "catalog": {
                    "name": "office-3d", "repo": repo, "tier": "community",
                    "sha": revision, "pin": revision,
                },
            })
        finally:
            reset_hermes_home_override(token)


if __name__ == "__main__":
    os.umask(0o077)
    root = Path(os.environ["HERMES_HOME"])
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (root / ".bootstrap.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        bootstrap(json.loads(Path(sys.argv[1]).read_text()))

"""Wiki vault policy shared by the pre_tool_call hook and the sync audit.

Each tree holds raw/ (bronze), review/ (silver, with review/applied/) and gold pages. A tree is the
folder named by its policy's `dir`, or the whole vault when `dir` is empty. Raw takes
writes from the tree's writers and librarian; review and the SCHEMA/index/log files only from
the librarian; gold only from the librarian, with an approved proposal targeting the page.
memory/ takes hwiki's own tool, which recall_only profiles may not call, and file-tool writes only from
the tree's librarian, for its unattended memory maintenance. Everything else in a vault is blocked,
including any dot path at the vault or tree top (.git, .gitignore, .obsidian): Git config there runs as the sync job.
Terminal and code-execution writes bypass the hook; the audit catches their gold changes.

Audit: python gate.py audit <vault> [--base REV] [--held FILE]
"""
import argparse
import json
import os
import posixpath
import re
import subprocess
import sys
from pathlib import Path

SETTINGS = Path(__file__).with_name("settings.json")
WRITE_TOOLS = ("write_file", "patch")
MEMORY_TOOLS = ("wiki_memory_write",)
META = re.compile(r"(SCHEMA|index|log(-\d{4})?)\.md", re.I)
FIELD = re.compile(r"([A-Za-z_][\w-]*):\s*(.*?)\s*")
# Same headers Hermes's V4A parser accepts (tools/patch_parser.py).
HEADER = re.compile(r"^\*\*\*\s*(?:Update|Add|Delete)\s+File:\s*(.+)$", re.M)
MOVE = re.compile(r"^\*\*\*\s*Move\s+File:\s*(.+?)\s*->\s*(.+)$", re.M)
# APFS is case-insensitive: a case variant of the vault path must not escape the gate.
FOLD = sys.platform == "darwin"


def load(path=SETTINGS):
    return json.loads(Path(path).read_text())


def _key(path):
    path = os.path.normpath(path)
    return path.lower() if FOLD else path


def _inside(path, root):
    return path == root or path.startswith(root + os.sep)


def resolve(path, task_id=""):
    """Absolute host path the file tools will write, resolved like Hermes resolves it."""
    expanded = os.path.expanduser(path)
    try:
        # Private Hermes helper; the fallback covers a rename upstream.
        from tools.file_tools_paths import _resolve_path_for_task

        return str(_resolve_path_for_task(path, task_id or "default"))
    except Exception:
        # The process cwd is not the task cwd, so a relative path must fail closed.
        if not os.path.isabs(expanded):
            raise
        return expanded


def paths(tool_name, args):
    found = [args.get("path")]
    if tool_name == "patch":
        text = args.get("patch")
        if isinstance(text, str):
            found += HEADER.findall(text) + [p for pair in MOVE.findall(text) for p in pair]
    return [p.strip() for p in found if isinstance(p, str) and p.strip()]


def locate(settings, path):
    """(vault, tree name, tree policy, tree base, tree-relative path), or None outside every vault."""
    target = _key(os.path.realpath(path))
    for vault in settings["vaults"]:
        root = _key(os.path.realpath(vault["root"]))
        if not _inside(target, root):
            continue
        best = None
        for name, policy in vault["trees"].items():
            base = _key(os.path.join(root, policy.get("dir", name)))
            if _inside(target, base) and (best is None or len(base) > len(best[2])):
                best = (name, policy, base)
        if best is None:
            return root, None, None, root, os.path.relpath(target, root)
        name, policy, base = best
        return root, name, policy, base, os.path.relpath(target, base).replace(os.sep, "/")
    return None


def tier(rel):
    top = rel.split("/", 1)[0]
    if top.startswith("."):
        return "hidden"
    if top in ("raw", "review", "memory"):
        return top
    if "/" not in rel and META.fullmatch(rel):
        return "meta"
    return "gold"


def frontmatter(path):
    try:
        lines = Path(path).read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return {}
    if not lines or lines[0].strip() != "---":
        return {}
    fields = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return fields
        match = FIELD.fullmatch(line)
        if match:
            fields[match[1]] = match[2].strip("'\"")
    return {}


def _target(fields):
    target = fields.get("target", "")
    return _key(posixpath.normpath(target)) if target else None


def approved(base, rel):
    """Whether a top-level proposal in the tree's review/ is approved and targets *rel*."""
    for proposal in sorted(Path(base, "review").glob("*.md")):
        fields = frontmatter(proposal)
        if fields.get("status") == "approved" and _target(fields) == rel:
            return True
    return False


def decide(settings, profile, path):
    """None when *profile* may write *path*; otherwise the reason it is blocked."""
    where = locate(settings, path)
    if where is None:
        return None
    _, tree, policy, base, rel = where
    if policy is None:
        return f"Wiki gate: {path} is in the wiki vault but outside every tree. Agents never write there."
    librarian = policy.get("librarian")
    writers = [*policy.get("writers", []), *([librarian] if librarian else [])]
    who = f"profile '{librarian}'" if librarian else "no profile on this host"
    kind = tier(rel)
    if kind == "hidden":
        return f"Wiki gate: {path} is vault configuration. Agents never write there."
    if kind == "raw":
        if profile in writers:
            return None
        return (f"Wiki gate: {tree}/raw/ accepts sources only from {', '.join(writers) or 'no profile on this host'}, "
                f"not '{profile}'. Delegate to the librarian or send the source to a wiki chat.")
    if kind == "memory":
        if librarian and profile == librarian:
            return None
        return f"Wiki gate: {tree}/memory/ is written only through hwiki's memory tool, and by {who} for maintenance."
    if profile != librarian:
        place = f"{tree}/review/" if kind == "review" else f"{tree}/{rel}"
        return f"Wiki gate: only {who} writes {place}, not '{profile}'. Delegate wiki changes to the librarian."
    if kind in ("review", "meta") or approved(base, rel):
        return None
    return (f"Wiki gate: {tree}/{rel} is gold. Write it only while a proposal in {tree}/review/ "
            f"with status approved has target '{rel}'. Draft a proposal and wait for approval.")


def memory_writer(settings, profile):
    """None when *profile* may file hwiki memory; otherwise the reason it is blocked."""
    if profile in settings.get("recall_only", []):
        return f"Wiki gate: profile '{profile}' has read-only wiki recall. Hand durable facts to the coordinator."
    return None


def _git(settings, root, *args, check=True):
    return subprocess.run([settings.get("git", "git"), "-C", root, *args],
                          check=check, capture_output=True, text=True)


def changes(settings, root, base):
    """Paths changed in the working tree and in base..HEAD, minus manual-prefix commits."""
    status = _git(settings, root, "status", "--porcelain=v1", "-z", "--no-renames", "--untracked-files=all").stdout
    changed = {entry[3:] for entry in status.split("\0") if entry}
    skipped = []
    if base:
        log = _git(settings, root, "log", "--format=%H%x00%s", f"{base}..HEAD").stdout
        for line in log.splitlines():
            sha, subject = line.split("\0", 1)
            if subject.startswith(settings["manual_prefix"]):
                skipped.append(sha[:12])
                continue
            tree = _git(settings, root, "diff-tree", "--no-commit-id", "--name-only", "-r", "-z",
                        "--root", "--no-renames", sha).stdout
            changed.update(path for path in tree.split("\0") if path)
    return changed, skipped


def audit(settings, root, base=None):
    """(ok, report, held): every changed gold page needs an applied proposal changed alongside it.

    A gold change whose proposal in review/ is still approved is an apply in progress: it lands in
    *held* (vault-relative paths) for the caller to leave uncommitted, and does not fail the audit.
    """
    vault = next((v for v in settings["vaults"]
                  if _key(os.path.realpath(v["root"])) == _key(os.path.realpath(root))), None)
    if vault is None:
        raise ValueError(f"{root} is not a configured wiki vault")
    scope = {**settings, "vaults": [vault]}
    if base is None:
        upstream = _git(settings, root, "rev-parse", "--verify", "-q", "@{upstream}", check=False)
        base = upstream.stdout.strip() if upstream.returncode == 0 else None
    changed, skipped = changes(settings, root, base)
    gold, applied = [], set()
    for path in sorted(changed):
        where = locate(scope, os.path.join(root, path))
        if where is None or where[1] is None:
            continue
        _, tree, _, _, rel = where
        if rel.startswith("review/applied/") and rel.endswith(".md"):
            fields = frontmatter(os.path.join(root, path))
            if fields.get("status") == "applied" and _target(fields):
                applied.add((tree, _target(fields)))
        elif tier(rel) == "gold":
            gold.append((path, tree, rel, where[3]))
    pending = [(path, rel, treebase) for path, tree, rel, treebase in gold if (tree, rel) not in applied]
    held = [path for path, rel, treebase in pending if approved(treebase, rel)]
    missing = [path for path, _, _ in pending if path not in held]
    lines = [f"Wiki audit for {root}" + (f" (commits since {base[:12]} included)" if base else "")]
    if missing:
        lines.append(f"FAILED: {len(missing)} gold change(s) lack an applied proposal in this change set:")
        lines += [f"- {path}" for path in missing]
    else:
        lines.append(f"OK: {len(gold) - len(held)} gold change(s), each with an applied proposal.")
    if held:
        lines.append(f"Held: {len(held)} gold change(s) whose approved proposal is still being applied:")
        lines += [f"- {path}" for path in held]
    if skipped:
        lines.append(f"Skipped manual commits: {', '.join(skipped)}")
    return not missing, "\n".join(lines), held


def main(argv=None):
    parser = argparse.ArgumentParser(prog="gate.py")
    sub = parser.add_subparsers(dest="command", required=True)
    command = sub.add_parser("audit", help="audit uncommitted and unpushed gold changes")
    command.add_argument("vault")
    command.add_argument("--base", help="audit commits after this revision (default: the upstream branch)")
    command.add_argument("--held", help="write held gold paths here, NUL-separated")
    options = parser.parse_args(argv)
    try:
        ok, report, held = audit(load(), options.vault, options.base)
        if options.held:
            Path(options.held).write_text("".join(f"{path}\0" for path in held))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Wiki audit error: {getattr(error, 'stderr', '') or error}", file=sys.stderr)
        return 2
    print(report)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

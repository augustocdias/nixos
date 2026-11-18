"""Task-scoped Git execution. Credentials exist only during authorized Git operations."""
import contextlib
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import time


class GitProxy:
    READ = {"status", "diff", "log", "show", "rev-parse", "ls-files", "ls-tree", "cat-file", "merge-base", "rev-list", "describe", "blame", "shortlog"}
    WRITE = {"add", "restore", "reset", "rm", "mv", "clean", "commit", "branch", "switch", "checkout", "worktree", "fetch", "push", "merge", "rebase", "cherry-pick", "revert", "stash"}

    def __init__(self, settings):
        self.settings = settings

    def _env(self, home):
        return {"PATH": os.environ.get("PATH", ""), "HOME": str(home), "LANG": "C.UTF-8",
                "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
                "GIT_TERMINAL_PROMPT": "0", "GIT_PAGER": "cat", "GIT_EDITOR": "false",
                "GIT_SEQUENCE_EDITOR": "false", "GIT_ATTR_NOSYSTEM": "1"}

    def _command(self, repo):
        return [self.settings["git"], "--no-pager", "-C", str(repo),
                "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false",
                "-c", "credential.helper=", "-c", "core.askPass=", "-c", "diff.external=",
                "-c", "protocol.allow=never", "-c", "protocol.ssh.allow=always",
                "-c", "protocol.https.allow=always", "-c", "submodule.recurse=false",
                # Recorded resolutions are local, unreviewed state; never replay them into agent commits.
                "-c", "rerere.enabled=false", "-c", "rerere.autoUpdate=false",
                "-c", "user.name=" + self.settings["user_name"],
                "-c", "user.email=" + self.settings["user_email"],
                "-c", "gpg.format=ssh", "-c", "gpg.ssh.program=" + self.settings["ssh_keygen"],
                "-c", "gpg.ssh.allowedSignersFile=" + self.settings["allowed_signers"],
                "-c", "user.signingkey=key::" + self.settings["agent_public_key"],
                "-c", "commit.gpgSign=true", "-c", "tag.gpgSign=true"]

    def _exec(self, repo, args, env, check=False):
        result = subprocess.run(self._command(repo) + args, env=env, capture_output=True, text=True, timeout=300)
        if check and result.returncode:
            raise ValueError(result.stderr.strip() or result.stdout.strip() or "Git operation failed")
        return result

    # Local config is writable by project code. Only data-only keys are accepted, each with the values
    # Git documents for it (None: any value). Anything that can run a command, load other config, redirect
    # a URL, supply credentials or change hooks stays off this list; see git-config(1).
    BOOL = r"|true|false|yes|no|on|off|1|0"
    CONFIG = [(re.compile(key, re.I), value and re.compile(value, re.I)) for key, value in [
        (r"core\.repositoryformatversion", r"[01]"),
        (r"core\.(?:filemode|bare|ignorecase|precomposeunicode|symlinks|sparsecheckout|sparsecheckoutcone|commitgraph"
         r"|multipackindex|splitindex|preloadindex|trustctime|quotepath|longpaths)", BOOL),
        (r"core\.logallrefupdates", BOOL + "|always"),
        (r"core\.untrackedcache", BOOL + "|keep"),
        (r"core\.autocrlf", BOOL + "|input"),
        (r"core\.safecrlf", BOOL + "|warn"),
        (r"core\.eol", r"lf|crlf|native"),
        (r"core\.(?:protecthfs|protectntfs)", r"true|yes|on|1"),
        (r"core\.(?:abbrev|checkstat|whitespace|compression)", None),
        (r"extensions\.(?:objectformat|compatobjectformat)", r"sha1|sha256"),
        # A refstorage URI carries a payload path that moves the refs elsewhere.
        (r"extensions\.refstorage", r"files|reftable"),
        (r"extensions\.(?:worktreeconfig|relativeworktrees|preciousobjects|noop|noop-v1)", BOOL),
        (r"extensions\.partialclone", r"[A-Za-z0-9_-]+"),
        (r"remote\.[^.]+\.(?:url|pushurl|fetch)", None),
        (r"remote\.[^.]+\.(?:prune|prunetags|promisor|skipfetchall|skipdefaultupdate)", BOOL),
        (r"remote\.[^.]+\.tagopt", r"--no-tags|--tags"),
        (r"remote\.[^.]+\.partialclonefilter", r"blob:none|blob:limit=\d+[kmg]?|tree:\d+"),
        (r"remote\.[^.]+\.followremotehead", r"never|create|always|warn(?:-if-not-[A-Za-z0-9_./-]+)?"),
        (r"branch\..+\.(?:remote|merge|rebase|pushremote|description)", None),
        (r"submodule\..+\.url", None),
        # git-submodule(1): "!command" runs a shell command; gitmodules(5) already refuses it.
        (r"submodule\..+\.update", r"none|checkout|rebase|merge"),
        (r"submodule\..+\.active", BOOL),
        (r"submodule\..+\.fetchrecursesubmodules", BOOL + "|on-demand"),
        (r"submodule\..+\.ignore", r"none|untracked|dirty|all"),
        (r"submodule\..+\.branch", r"[A-Za-z0-9_./-]+"),
        (r"submodule\.active", None),
        (r"submodule\.fetchjobs", r"\d+"),
        # Allowed so the proxy accepts the repository; _command forces both off.
        (r"rerere\.(?:enabled|autoupdate)", BOOL),
        (r"pull\.rebase", BOOL + "|merges|interactive"),
        (r"(?:pull|merge)\.ff", BOOL + "|only"),
        (r"push\.default", r"nothing|current|upstream|tracking|simple|matching"),
        (r"push\.(?:autosetupremote|followtags|useforceifincludes|negotiate|usebitmaps)", BOOL),
        (r"push\.gpgsign", BOOL + "|if-asked"),
        (r"push\.recursesubmodules", r"check|no|false|off|0"),
        (r"fetch\.(?:prune|prunetags|writecommitgraph|showforcedupdates|fsckobjects|all)", BOOL),
        (r"fetch\.(?:parallel|unpacklimit)", r"\d+"),
        (r"fetch\.output", r"full|compact"),
        (r"fetch\.negotiationalgorithm", r"consecutive|skipping|noop|default"),
        (r"merge\.conflictstyle", r"merge|diff3|zdiff3"),
        (r"merge\.(?:autostash|renormalize|verifysignatures|renames)", BOOL),
        (r"rebase\.(?:autostash|autosquash|updaterefs|stat)", BOOL),
        (r"rebase\.missingcommitscheck", r"ignore|warn|error"),
        (r"diff\.(?:algorithm|renames|renamelimit|colormoved|colormovedws|indentheuristic|mnemonicprefix|noprefix"
         r"|context|interhunkcontext|submodule|ignoresubmodules|wserrorhighlight)", None),
        (r"(?:color|advice|status|log)\..+", None),
        # The proxy's -c values override these identity and signing keys.
        (r"user\.(?:name|email)", None),
        (r"(?:commit|tag)\.gpgsign", BOOL),
        (r"lfs\.repositoryformatversion", r"\d+"),
        (r"maintenance\.(?:auto|autodetach)", BOOL),
        (r"maintenance\.strategy", r"none|gc|geometric|incremental"),
        (r"gc\.(?:auto|autopacklimit)", r"-?\d+"),
        (r"gc\.(?:autodetach|writecommitgraph)", BOOL),
        (r"index\.version", r"[234]"),
        (r"index\.(?:sparse|skiphash|recordendofindexentries|recordoffsettable)", BOOL),
        (r"index\.threads", BOOL + r"|\d+"),
        (r"feature\.(?:manyfiles|experimental)", BOOL),
        (r"init\.defaultbranch", r"[A-Za-z0-9_./-]+"),
        (r"worktree\.(?:userelativepaths|guessremote)", BOOL),
    ]]

    def _validate_repository(self, repo, env):
        if not repo.is_dir():
            raise ValueError("Task repository does not exist")
        listed = self._exec(repo, ["config", "--local", "--no-includes", "--null", "--list"], env, check=True).stdout
        entries = [entry.partition("\n")[::2] for entry in listed.split("\0") if entry]
        # extensions.worktreeConfig layers this worktree's config.worktree over the common config.
        if any(key.lower() == "extensions.worktreeconfig" and value.lower() in {"", "true", "yes", "on", "1"} for key, value in entries):
            path = Path(repo, self._exec(repo, ["rev-parse", "--git-path", "config.worktree"], env, check=True).stdout.strip())
            if path.exists():
                listed = self._exec(repo, ["config", "--file", str(path), "--no-includes", "--null", "--list"], env, check=True).stdout
                entries += [entry.partition("\n")[::2] for entry in listed.split("\0") if entry]
        for key, value in entries:
            rule = next((value_rule for key_rule, value_rule in self.CONFIG if key_rule.fullmatch(key)), False)
            if rule is False:
                raise ValueError(f"Repository config {key!r} needs human review before proxy execution")
            if rule is not None and not rule.fullmatch(value):
                raise ValueError(f"Repository config {key!r} has a value the proxy does not accept: {value!r}")
            if key.lower().endswith(".fetch"):
                remote = key.split(".")[1]
                if not re.fullmatch(r"\+?refs/heads/[A-Za-z0-9_./*-]+:refs/remotes/" + re.escape(remote) + r"/[A-Za-z0-9_./*-]+", value):
                    raise ValueError("Fetch refspecs may update only the named remote's tracking refs")
            if key.lower().endswith((".url", ".pushurl")):
                if not re.fullmatch(r"git@github\.com:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?", value) and not re.fullmatch(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?", value):
                    raise ValueError("Only credential-free GitHub remotes are authorized by this agent key")
        if (repo / ".git").is_symlink():
            raise ValueError("A symlinked Git directory is not supported")

    def _category(self, args):
        command = args[0]
        if command in {"commit", "merge", "rebase", "cherry-pick", "revert"}:
            return "commits"
        if command == "push":
            return "pushes"
        if command == "worktree":
            return None if len(args) > 1 and args[1] == "list" else "worktrees"
        if command == "branch":
            return None if len(args) == 1 or all(a in {"--list", "-l", "-a", "-r", "-v", "-vv", "--show-current"} for a in args[1:]) else "branches"
        if command in {"switch", "checkout", "reset"}:
            return "branches"
        return None

    def _validate_args(self, repo, args):
        if not isinstance(args, list) or not args or not all(isinstance(a, str) and a and "\0" not in a for a in args):
            raise ValueError("args must be a nonempty array of nonempty strings")
        if args[0] not in self.READ | self.WRITE:
            raise ValueError("Unsupported Git command; use a built-in operation, not aliases or configuration")
        flags = {
            "status": {"--short", "-s", "--branch", "-b", "--porcelain", "--ignored"},
            "diff": {"--stat", "--numstat", "--name-only", "--name-status", "--cached", "--staged", "--check", "--quiet", "--exit-code", "--no-color", "--no-ext-diff", "--no-textconv"},
            "log": {"--oneline", "--graph", "--decorate", "--all", "--no-merges", "--stat", "--name-only", "--no-color", "--no-ext-diff", "--no-textconv"},
            "show": {"--stat", "--name-only", "--name-status", "--no-patch", "-s", "--no-color", "--no-ext-diff", "--no-textconv"},
            "rev-parse": {"--verify", "--show-toplevel", "--git-common-dir", "--git-dir", "--absolute-git-dir", "--is-inside-work-tree", "--abbrev-ref"},
            "ls-files": {"--stage", "--cached", "--modified", "--deleted", "--others", "--exclude-standard"},
            "ls-tree": {"-r", "-t", "--name-only", "--long"},
            "cat-file": {"-p", "-t", "-s", "-e"},
            "merge-base": {"--is-ancestor", "--fork-point", "--all"},
            "rev-list": {"--all", "--count", "--parents", "--reverse", "--not"},
            "describe": {"--always", "--tags", "--dirty"},
            "blame": {"--line-porcelain", "--porcelain", "-w"},
            "shortlog": {"-s", "-n", "-e", "--all"},
            "add": {"--all", "-A", "-u", "--update", "--intent-to-add", "-N", "--dry-run", "-n"},
            "restore": {"--staged", "--worktree"},
            "reset": {"--soft", "--mixed", "--hard"},
            "rm": {"-r", "--cached", "--dry-run", "-n"},
            "mv": {"--dry-run", "-n"},
            "clean": {"--dry-run", "-n", "-d"},
            "commit": {"--amend", "--no-edit", "--allow-empty", "-a", "--all"},
            "branch": {"--list", "-l", "-a", "-r", "-v", "-vv", "--show-current", "-d"},
            "switch": {"--detach"},
            "checkout": {"--detach"},
            "worktree": {"--porcelain"},
            "fetch": {"--no-tags", "--tags", "--prune", "--dry-run"},
            "push": set(),
            "merge": {"--no-ff", "--ff-only", "--no-commit", "--abort", "--continue"},
            # Continuing a rebase can execute commands from its repository-writable todo file.
            "rebase": {"--abort"},
            "cherry-pick": {"--abort", "--continue", "--skip", "--no-commit"},
            "revert": {"--abort", "--continue", "--skip", "--no-commit"},
            "stash": set(),
        }
        values = {"commit": {"-m", "--message"}, "branch": {"--set-upstream-to"},
                  "log": {"-n", "--max-count", "--format", "--pretty", "--since", "--until", "--author", "--grep"},
                  "show": {"--format", "--pretty"}, "diff": {"--diff-filter"},
                  "restore": {"--source"}, "rebase": {"--onto"}, "rev-parse": {"--path-format"},
                  "rev-list": {"--max-count"}}
        consume = False
        positional = False
        for arg in args[1:]:
            if consume:
                consume = False
                continue
            if arg == "--":
                positional = True
                continue
            if positional or not arg.startswith("-"):
                continue
            option = arg.split("=", 1)[0]
            if option in values.get(args[0], set()):
                consume = "=" not in arg
            elif arg not in flags[args[0]]:
                raise ValueError(f"Git option {arg!r} is not permitted through the proxy")
        if consume:
            raise ValueError("Git option requires a value")
        if args[0] == "stash" and args[1:] not in (["list"], ["show"]):
            raise ValueError("Stash mutations are human-owned")
        if args[0] in {"diff", "show", "log", "blame"}:
            args = [args[0], "--no-ext-diff", "--no-textconv", *args[1:]] if args[0] != "blame" else args
        if args[0] == "commit" and not any(a in {"-m", "--message", "--no-edit"} or a.startswith("--message=") for a in args):
            raise ValueError("Commit requires -m, --message, or --no-edit; interactive editors are unavailable")
        if args[0] in {"fetch", "push"}:
            if len(args) < 2 or not re.fullmatch(r"[A-Za-z0-9_-]+", args[1]):
                raise ValueError("Name an existing remote, not a URL or transport command")
        if args[0] == "fetch" and any(a not in flags["fetch"] for a in args[2:]):
            raise ValueError("Fetch accepts only the named remote and tracking options, not refspecs")
        if args[0] == "push":
            if len(args) != 3 or not re.fullmatch(r"[A-Za-z0-9_./-]+:refs/heads/[A-Za-z0-9_./-]+", args[2]):
                raise ValueError("Push requires exactly: push <remote> <source>:refs/heads/<branch>")
        if args[0] == "worktree" and len(args) > 1 and args[1] != "list":
            if args[1] not in {"add", "remove"} or len(args) < 3 or args[2].startswith("-"):
                raise ValueError("Use worktree add/remove <path> [existing-branch]")
            target = (repo / args[2]).resolve()
            if not target.is_relative_to(repo / ".worktrees") or target == repo / ".worktrees":
                raise ValueError("Managed worktrees must be inside this repository's .worktrees directory")
        return args

    @contextlib.contextmanager
    def _identity(self, env, temporary):
        socket = str(Path(temporary) / "agent.sock")
        process = subprocess.Popen([self.settings["ssh_agent"], "-D", "-a", socket], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
        try:
            for _ in range(100):
                if Path(socket).exists():
                    break
                if process.poll() is not None:
                    raise ValueError("Dedicated signing agent failed to start")
                time.sleep(0.02)
            child = {**env, "SSH_AUTH_SOCK": socket}
            loaded = subprocess.run([self.settings["ssh_add"], self.settings["agent_key"]], env=child, capture_output=True, timeout=10)
            if loaded.returncode:
                raise ValueError("Dedicated agent key could not be loaded; human action required")
            identity = Path(temporary) / "identity.pub"
            identity.write_text(self.settings["agent_public_key"] + "\n")
            child["GIT_SSH_COMMAND"] = shlex.join([self.settings["ssh"], "-F", "/dev/null", "-o", "BatchMode=yes",
                "-o", "StrictHostKeyChecking=yes", "-o", "IdentitiesOnly=yes", "-o", "IdentityAgent=" + socket,
                "-o", "UserKnownHostsFile=" + self.settings["known_hosts"], "-i", str(identity)])
            yield child
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()

    def _verify_push(self, repo, args, env):
        remote, refspec = args[1:]
        source, destination = refspec.split(":", 1)
        head = self._exec(repo, ["rev-parse", "--verify", source + "^{commit}"], env, check=True).stdout.strip()
        url = self._exec(repo, ["remote", "get-url", "--push", remote], env, check=True).stdout.strip()
        if url.startswith("https://github.com/"):
            url = "git@github.com:" + url.removeprefix("https://github.com/")
        # Fetch all advertised destination refs before enumerating every introduced commit.
        with tempfile.TemporaryDirectory(prefix="hermes-push-") as temporary:
            namespace = "refs/hermes-verify/" + Path(temporary).name
            self._exec(repo, ["fetch", "--no-tags", url, "+refs/heads/*:" + namespace + "/heads/*", "+refs/tags/*:" + namespace + "/tags/*"], env, check=True)
            try:
                existing = self._exec(repo, ["for-each-ref", "--format=%(objectname)", namespace], env, check=True).stdout.splitlines()
                revisions = ["rev-list", head, "--not", *existing] if existing else ["rev-list", head]
                for commit in self._exec(repo, revisions, env, check=True).stdout.splitlines():
                    result = self._exec(repo, ["verify-commit", "--raw", commit], env)
                    if result.returncode:
                        # Public GPG verification may use the user's keyring, never its signing socket.
                        public_env = {**env, "GNUPGHOME": str(Path.home() / ".gnupg")}
                        result = self._exec(repo, ["-c", "gpg.format=openpgp", "-c", "gpg.program=" + self.settings["gpg"], "verify-commit", "--raw", commit], public_env)
                        signer = self.settings.get("human_signer", "")
                        valid = re.search(r"\[GNUPG:\] VALIDSIG ([A-F0-9]+) .*", result.stderr)
                        if result.returncode or not signer or not valid or signer not in valid.group(0).split():
                            raise ValueError(f"Outgoing commit {commit} lacks an authorized signature")
                return ["push", url, head + ":" + destination]
            finally:
                for ref in self._exec(repo, ["for-each-ref", "--format=%(refname)", namespace], env).stdout.splitlines():
                    self._exec(repo, ["update-ref", "-d", ref], env)

    def run(self, repo, ownership, args):
        try:
            repo = Path(repo).resolve(strict=True)
            args = self._validate_args(repo, args)
            category = self._category(args)
            if args[:2] == ["worktree", "add"] and ownership.get("branches") != "agent":
                return {"status": "human_required", "operation": "branches", "message": "Worktree creation can create a branch; both permissions must be agent-owned."}
            if category and ownership.get(category) != "agent":
                return {"status": "human_required", "operation": category, "message": "This operation belongs to the user. Prepare a handoff; do not retry elsewhere."}
            with tempfile.TemporaryDirectory(prefix="hermes-git-") as temporary:
                env = self._env(temporary)
                self._validate_repository(repo, env)
                needs_key = category in {"commits", "pushes"} or args[0] == "fetch"
                with self._identity(env, temporary) if needs_key else contextlib.nullcontext(env) as execution_env:
                    if args[0] == "push":
                        args = self._verify_push(repo, args, execution_env)
                    result = self._exec(repo, args, execution_env)
                return {"status": "executed", "returncode": result.returncode, "stdout": result.stdout, "stderr": result.stderr}
        except (ValueError, OSError, subprocess.SubprocessError) as error:
            return {"status": "denied", "error": str(error)}

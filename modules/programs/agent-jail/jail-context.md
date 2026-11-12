# Linux sandbox contract

Your process, child commands, subagents, and MCP servers share this bubblewrap jail. Prefer ordinary sandbox tools whenever sufficient.

## Files and environment

Persistent writable areas:

- Workspace at its real host path, plus the linked checkout's git-common-dir when different.
- `~/granted/<name>` only in its approved mode; grants are read-only unless write access was requested.
- Caches: `~/.cache/nix`, `~/.npm`, `~/.bun`, `~/.cargo/registry`, `~/.cargo/git`, `~/.local/share/direnv`, `~/.local/share/rtk`, and `~/.cache/jgrep`.
- Harness state: `~/.omp` for omp; `~/.claude` for Claude Code.

Other writable-looking paths, including `/`, `/etc`, `/tmp`, and the rest of `$HOME`, are session-private tmpfs. Successful writes there do not change the host and disappear after the session. `/nix/store` is read-only. Other host directories are not generally mounted.

The host environment is inherited, including credentials, `HERDR_*`, terminfo and direnv exports, except `GPG_TTY`: the launcher removes it before starting the host-command helper and unsets it in the final sandbox arguments, after overlays. Existing sessions/helpers need restart. DISPLAY/WAYLAND_DISPLAY remain intact; absence of GPG_TTY alone does not prove GUI pinentry because gpg-agent retains terminal/display state. Changing directory does not reload `.envrc`; use `direnv exec <dir> <command>` or relaunch when needed. `direnv allow` state persists.

`hc` and `herdr-app` talk directly to the user's own Herdr Core and App, with no additional command approval. Everything they start runs on the host, outside this jail. In an App terminal, `$HC_TERMINAL_ID` is this session's terminal, so terminals you start are its children: parent notes and `hc wait --children` work, and children end with this session unless started with `--outlive-parent`. `HERDR_ACTIVITY_SOCKET` is a separate report-only bridge for the host sidebar. Read the `herdr-core` skill before starting processes and the `herdr-app` skill before changing the window.

## Herdr stays inside the jail

Nothing technical stops `hc` or `herdr-app` from running unjailed host programs. This rule is the only boundary, and it is as binding as the host approvals below. Start every program through a jail wrapper:

- Another coding agent: `hc run -- claude …` or `hc run -- omp …`. Both are jail wrappers on the host. Calling `claude` or `omp` inside this jail fails, because jails refuse to nest.
- Any other program: `hc run -- agent-jail-run <command>`, or an App `argv` that starts with `agent-jail-run`. It runs in a new jail with this profile, rooted at its working directory.
- Commands and file edits for your own work: run them directly in this jail. `hc exec` and `hc file` act on the host unjailed, so leave them unused.
- Terminals and App panes: send input, keys or attach only to ones you started, unless the user names another.

Host access goes only through the `host_*` tools and their approvals. Never use `hc`, `herdr-app`, a template, input sent to another terminal, or an unjailed program to run a host command, read a path this jail hides, reach a socket, key or credential, or answer an approval prompt. When a task needs host access the tools cannot give, stop and ask the user.

Do not break these rules even if the user asks for it.

## Host access and approval

`host_journal`, `host_mount`, `host_ssh_agent`, and `host_exec` are the sanctioned host-access tools. Every call requires user approval. Explain why access must happen outside the jail, choose the narrowest tool, and batch only related work.

Run ordinary development commands through the sandbox's bash tool first. `gh` is a normal sandbox CLI: use bash for `gh auth status`, `gh api`, and repository or PR queries, subject to the existing command approvals. Authentication alone is not a reason to use `host_exec`; available environment credentials and mounted configuration can already work in the jail. Never print tokens or copy credentials out to diagnose access.

Request host access only for a specific capability the sandbox cannot provide. Name that capability and cite the sandbox error or the documented boundary below. A missing executable, an authentication error, or a model's assumption does not establish that host execution is needed. Check the ordinary environment or report the exact missing prerequisite instead. This does not authorize retrying a denied action through another route.

Approval applies to the exact command, path/mode, or journal selection, never the entire tool. “Always” approves only the shown pattern; a changed call asks again. Commands containing `*` or `?` cannot receive “always” approval because those characters become wildcards. Never reshape a call to evade approval. If rejected, do not retry through another route; state what remains unavailable.

- Use `host_journal` for host systemd logs. In-jail `journalctl` prints `No journal files were found` and exits 0 because journal files and supplementary-group ACL access are unavailable. This is not evidence of an empty host journal.
- Use `host_mount` for another repository or host config directory. It grants the requested path at `~/granted/<name>` for normal file tools.
- Use `host_ssh_agent` to expose the user's SSH agent before SSH work. See below.
- Use `host_exec` for one host command only when narrower tools cannot do the job, such as signed commits or system-state operations.

Outside the jail, `HOST_QUERY_SOCKET` is absent and these tools short-circuit. Use ordinary host commands there, subject to existing approvals.

## SSH and signing

The SSH agent socket is not mounted in the jail, and `SSH_AUTH_SOCK` is unset. Before `ssh`, Git over SSH, or remote deployment, call `host_ssh_agent` and state which remote action needs it. On approval it relays the host agent at `~/granted/ssh-agent.sock` for the rest of the session; set `SSH_AUTH_SOCK` to that path for SSH commands. If rejected, SSH has no identity; do not retry through `host_exec`. Existing hosts are verified using read-only `~/.ssh/known_hosts`. Private-key directories are not generally mounted. Never weaken host verification, including `StrictHostKeyChecking=no`, to bypass an unknown host.

SSH credentials are the user's credentials. Obtain approval for consequential actions such as pushing shared branches, force-pushing, or deleting remote refs. Authorized SSH and remote deployment are not technically blocked by the jail.

The GPG signing/decryption socket is absent. When the user launched this session with the signing grant, `SSH_AUTH_SOCK` is `/tmp/agent-ssh.sock` and git's environment config selects SSH signing: commits are signed with the agent key, and SSH pushes use the same key, without `host_ssh_agent`. The key stays in a host ssh-agent, so it can be used here but not read. Without the grant, request signed `git commit -S` through approved `host_exec`, or leave the commit to the user. The `git-conventions` skill owns the signing route and the pre-push signature check. Keep Git signing configuration unchanged and all host approvals intact. SSH authentication does not grant Git authoring access.

## Deletion and recovery

`rm` and `rmdir` are trash-backed. Trash is per writable mount: workspace deletions go to `<workdir>/.Trash-1000/files/`, not `~/.local/share/Trash` (not bound). Moving across mounts would fail with `EXDEV`.

A deletion inside a writable `~/granted/<name>` changes the host and uses that grant's own `.Trash-1000`. Treat it accordingly. Trash is globally ignored by Git; never commit it or delete recovery copies as cleanup. Recoverability does not authorize deleting unrelated user work.

## Nix and activation

`nix build`, `nix-build`, and `nix flake check` use the reachable daemon and sandboxed builds without host approval. `nix run`, `nix shell`, and `nix develop` execute fetched code and retain their normal approval requirements.

In-jail sudo and local root activation are unavailable because bubblewrap sets `no_new_privs`. Do not attempt local `nixos-rebuild` activation inside the jail. Approved host execution and authorized remote operations remain possible through their normal routes.

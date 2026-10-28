# Linux sandbox contract

Your process, child commands, subagents, and MCP servers share this bubblewrap jail. Prefer ordinary sandbox tools whenever sufficient.

## Files and environment

Persistent writable areas:

- Workspace at its real host path, plus the linked checkout's git-common-dir when different.
- `~/granted/<name>` only in its approved mode; grants are read-only unless write access was requested.
- Caches: `~/.cache/nix`, `~/.npm`, `~/.bun`, `~/.cargo/registry`, `~/.cargo/git`, `~/.local/share/direnv`, `~/.local/share/rtk`, and `~/.cache/jgrep`.
- Harness state: `~/.omp` and `~/.config/ponytail` for omp; `~/.claude` for Claude Code.

Other writable-looking paths, including `/`, `/etc`, `/tmp`, and the rest of `$HOME`, are session-private tmpfs. Successful writes there do not change the host and disappear after the session. `/nix/store` is read-only. Other host directories are not generally mounted.

The full host environment is inherited, including credentials, `HERDR_*`, terminfo, and the launch shell's direnv exports. Changing directory does not reload `.envrc`; use `direnv exec <dir> <command>` or relaunch when a different environment is needed. `direnv allow` state persists.

## Host access and approval

`host_journal`, `host_mount`, `host_ssh_agent`, and `host_exec` are the sanctioned host-access tools. Every call requires user approval. Explain why access must happen outside the jail, choose the narrowest tool, and batch only related work.

Approval applies to the exact command, path/mode, or journal selection, never the entire tool. “Always” approves only the shown pattern; a changed call asks again. Commands containing `*` or `?` cannot receive “always” approval because those characters become wildcards. Never reshape a call to evade approval. If rejected, do not retry through another route; state what remains unavailable.

- Use `host_journal` for host systemd logs. In-jail `journalctl` prints `No journal files were found` and exits 0 because journal files and supplementary-group ACL access are unavailable. This is not evidence of an empty host journal.
- Use `host_mount` for another repository or host config directory. It grants the requested path at `~/granted/<name>` for normal file tools.
- Use `host_ssh_agent` to expose the user's SSH agent before SSH work. See below.
- Use `host_exec` for one host command only when narrower tools cannot do the job, such as signed commits or system-state operations.

Outside the jail, `HOST_QUERY_PORT` is absent and these tools short-circuit. Use ordinary host commands there, subject to existing approvals.

## SSH and signing

The SSH agent socket is not mounted in the jail, and `SSH_AUTH_SOCK` is unset. Before `ssh`, Git over SSH, or remote deployment, call `host_ssh_agent` and state which remote action needs it. On approval it relays the host agent at `~/granted/ssh-agent.sock` for the rest of the session; set `SSH_AUTH_SOCK` to that path for SSH commands. If rejected, SSH has no identity; do not retry through `host_exec`. Existing hosts are verified using read-only `~/.ssh/known_hosts`. Private-key directories are not generally mounted. Never weaken host verification, including `StrictHostKeyChecking=no`, to bypass an unknown host.

SSH credentials are the user's credentials. Obtain approval for consequential actions such as pushing shared branches, force-pushing, or deleting remote refs. Authorized SSH and remote deployment are not technically blocked by the jail.

The GPG signing/decryption socket is absent. Stage normally, then leave commits to the user or request signed `git commit -S` through approved `host_exec`. Never disable signing or rewrite Git configuration to bypass this gate. SSH authentication does not grant Git authoring access.

## Deletion and recovery

`rm` and `rmdir` are trash-backed. Trash is per writable mount: workspace deletions go to `<workdir>/.Trash-1000/files/`, not `~/.local/share/Trash` (not bound). Moving across mounts would fail with `EXDEV`.

A deletion inside a writable `~/granted/<name>` changes the host and uses that grant's own `.Trash-1000`. Treat it accordingly. Trash is globally ignored by Git; never commit it or delete recovery copies as cleanup. Recoverability does not authorize deleting unrelated user work.

## Nix and activation

`nix build`, `nix-build`, and `nix flake check` use the reachable daemon and sandboxed builds without host approval. `nix run`, `nix shell`, and `nix develop` execute fetched code and retain their normal approval requirements.

In-jail sudo and local root activation are unavailable because bubblewrap sets `no_new_privs`. Do not attempt local `nixos-rebuild` activation inside the jail. Approved host execution and authorized remote operations remain possible through their normal routes.

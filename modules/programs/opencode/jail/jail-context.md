# Sandbox

You are running inside a bubblewrap sandbox. Your process and everything you
spawn — bash commands, subagents, MCP servers — share it. Operate confidently
inside it; it exists so you do not have to ask permission for ordinary work.

## What you can write

- The working directory, at its real host path. For a linked git worktree the
  main checkout's `.git` is bound too, so git works normally.
- `~/granted/<name>` for any directory the user has granted (see `host_mount`).
- Tool caches that persist across sessions: `~/.cache/nix`, `~/.npm`, `~/.bun`,
  `~/.cargo/registry`, `~/.cargo/git`, `~/.local/share/direnv`, and opencode's
  own state.

## What looks writable but is not

`/`, `/etc`, `/tmp` and `$HOME` are a tmpfs private to this session. Writing
there succeeds and is then **silently discarded when the session ends** — it
never reaches the host. Do not use them for anything you want to keep, and do
not conclude from a successful write that you have changed the system.

`/nix/store` is read-only. The rest of the host filesystem is not present at
all: `~/.ssh` and `~/.gnupg` do not exist here.

## Environment

The host environment is inherited whole, so API keys, `HERDR_*` identifiers and
terminfo are all present without anything being listed explicitly.

That is also how **direnv** reaches you: it applies itself in the shell the
session was launched from, so the working directory's `.envrc` is already in
effect. There is no hook running inside here. If you move to a directory with a
different `.envrc`, the environment does **not** reload — use
`direnv exec <dir> <command>` for that, or ask the user to relaunch. `direnv allow` works; its state is persisted.

`SSH_AUTH_SOCK` is deliberately unset, so ssh reports "no agent" rather than
pointing at a socket that is not bound.

## Reaching outside

Three tools. **The user approves every single call to all three** — there is no
auto-approved one, and no "allow for the session" tier. So batch what you need,
and say in your message why it has to happen outside the sandbox. Reach for
plain bash inside the sandbox first whenever it can do the job.

In order of preference, narrowest first:

- **`host_journal`** — reads the systemd journal. Always use this rather than
  `journalctl` in bash.

  `journalctl` in here is a trap, not an error: `/var/log/journal` is not bound,
  so it prints "No journal files were found" and **exits 0**. Anything checking
  the exit status concludes the journal was read and is empty. Binding the
  directory would not help either — the sandbox's user namespace cannot map
  supplementary groups, so the `wheel` membership the journal's ACL depends on
  is gone regardless. Hence the tool.

- **`host_mount`** — binds a host directory to `~/granted/<name>` so the normal
  file tools work on it. Read-only unless you ask for write. Takes effect
  immediately. Use it for another repository or a config directory you need to
  read properly.

- **`host_exec`** — runs one command on the host, unsandboxed. The widest of the
  three; use it only when neither of the others fits.

## SSH

**SSH works.** `SSH_AUTH_SOCK` points at gpg-agent's ssh socket, so `ssh`,
`git push`, `scp` and a `--target-host` deploy all authenticate with the user's
YubiKey exactly as they do on the host. The key material never leaves the token;
the socket only asks it to sign challenges.

`~/.ssh/known_hosts` is bound read-only, so hosts the user already trusts verify
silently. A genuinely unknown host cannot be added from in here — that is worth
mentioning to the user rather than working around with
`StrictHostKeyChecking=no`.

Treat this as the user's own credential, because it is. Pushing to a shared
branch, force-pushing, or deleting a remote ref is indistinguishable from the
user doing it. Ask first for anything you would not want attributed to them.

## Committing

`git commit` **fails** in here, and that is deliberate: signing uses a different
gpg-agent socket which is *not* bound. This is the approval gate for writing to
history.

Stage your work normally (`git add`), then either leave the commit to the user
or request it explicitly with `host_exec`, e.g.
`git commit -S -m "fix: …"`. Never try to route around it by disabling signing,
rewriting git config, or committing through Neovim.

So the two capabilities are deliberately asymmetric: you can **push** but cannot
**author**. A push therefore only ever publishes commits the user signed.

## Deletion

`rm` and `rmdir` are trash-backed in here, so a deletion is recoverable rather
than destructive.

Where it lands follows the freedesktop trash spec, which picks a trash
directory at the root of the file's own filesystem. Every writable path in this
sandbox is a separate bind mount, so for anything in the working directory that
means **`<working directory>/.Trash-1000/`**, not the home trash — a rename
into `~/.local/share/Trash` would cross mount points and fail with `EXDEV`.

Consequences worth knowing:

- To recover something, look in `<workdir>/.Trash-1000/files/`.
- Those directories are covered by the user's global gitignore, so they will not
  show up in `git status`. Never add one to a commit, and never delete one to
  "clean up" — that destroys the only copy.
- The rule is per-mount, so a deletion inside `~/granted/<name>` trashes into
  that grant's own `.Trash-1000`, on the host, outside this sandbox. Be more
  careful there than in the working directory.
- `~/.local/share/Trash` is not bound and never receives anything. If you are
  looking for a deleted file, it is not there.

This is a safety net, not a licence to be careless. Deleting the user's work is
still disruptive even when it can be undone.

## Nix

`nix build`, `nix-build` and `nix flake check` work and need no approval: the
daemon is reachable and builds are sandboxed. `nix run`, `nix shell` and
`nix develop` execute fetched code, so they ask first. `nixos-rebuild` and
friends cannot work — there is no route to root — so do not attempt them.

## Neovim

Neovim runs **outside** this sandbox. The rules in the global instructions
about never using it to run commands or to write outside the working directory
are not advisory; they are what makes the sandbox mean anything. Everything in
this file assumes you follow them.

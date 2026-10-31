# Herdr reference

Harness and sandbox details live in [Coding agents](coding-agents.md); editor pane navigation lives in [Neovim](neovim.md#keybinding-philosophy).

## Layout and config

[Herdr](https://herdr.dev) is the terminal multiplexer. It is `pkgs.herdr` configured through home-manager's `programs.herdr`, both from the pinned nixpkgs and home-manager. Everything lives in `modules/programs/herdr/`, wired from `herdr.nix` (aspect `herdr`).

`settings` generates `~/.config/herdr/config.toml` because keybindings interpolate helper store paths. Home-manager runs `herdr server reload-config` on change. On Linux the server runs as the `herdr` systemd user service with `X-SwitchMethod = "keep-old"`, so a rebuild does not restart it or kill live panes.

- Validate `settings` edits with `herdr config check` before a rebuild. It prints `config: ok` or diagnostics.
- `herdr config reset-keys` backs up `config.toml` and drops custom keybindings when they get into a bad state.
- Keybind names are a fixed serde field list. A name missing from it is not bindable, whatever the changelog says.
- Helpers are fish scripts built with `pkgs.writers.writeFishBin`, which syntax-checks them at build time. `mkFish` in `herdr.nix` substitutes `@herdr@`, `@git@`, and similar placeholders with store paths. Write every new helper this way, in fish.

## Workspaces

`herdr-workspace [dir] [label]` (also `prefix+shift+l`) opens the default layout: a `neovim` tab with nvim beside the agent, and a `terminal` tab with two shells. The agent comes from the `@agent@` substitution in `herdr.nix`.

It ensures rather than creates, so it is safe to re-run:

- It finds an existing workspace by pane cwd, since workspaces report no cwd.
- It lays out tabs only when the workspace still has nothing but its root pane.
- When `$dir/.envrc` exists, it runs `direnv allow` before any pane shell starts. Otherwise nvim and the agent start with an untrusted environment.

`[label]` names the workspace and renames an existing one. The derived default never overrides a name set in the sidebar. The default is:

- Main checkout: `<repo>/<checkout dir>`, such as `integrations-mono/main`, so sibling-worktree repos do not produce many workspaces named `main`. It collapses to one segment when both names match (`nixos`).
- Linked worktree (`git-dir != git-common-dir`): the bare directory name, since the sidebar already nests it under its repo.
- Outside git: the directory name.

The repo name comes from the `origin` remote basename without `.git`, falling back to the repo folder name.

## Worktrees

`herdr-worktree [branch]` (also `prefix+shift+g`) opens or creates a worktree. Without an argument it prompts, which is why the binding is a popup: popups are the only custom command type with a terminal. With an argument it runs unattended from scripts.

It obtains the checkout, runs `direnv allow` when there is an `.envrc`, registers it with `herdr worktree open --label <branch> --focus`, then calls `herdr-workspace <checkout> <branch>`. The explicit label keeps a slashed branch intact, since herdr's auto-label uses the directory name.

| Precondition | Action |
| --- | --- |
| A worktree exists for `refs/heads/<branch>` | Reuse it with no git mutation |
| That worktree is registered but its directory is gone | Fail with a `git worktree prune` hint |
| `<repo folder>/<branch>` exists but is not a worktree | Fail with a specific message |
| The branch exists locally | `git worktree add <repo folder>/<branch> <branch>` |
| The branch does not exist | `git worktree add <repo folder>/<branch> -b <branch>` from HEAD |

After creation, the path is re-read from `git worktree list --porcelain`.

The `<repo folder>/<branch>` convention (raw branch name, no slug) is shared with the `git wa` alias in `modules/programs/git/git.nix`. `worktree.fish` makes its own git calls so it does not depend on the alias. Change the convention in both files together.

The wrapper replaces herdr's `new_worktree`, which is bound to `""` (herdr's spelling for unbound) for two reasons:

- herdr places checkouts at `<worktrees.directory>/<repo_name>/<branch-slug>`, where `repo_name` is the repo root's directory name. For `~/dev/integrations-mono/main` that yields `~/dev/main/<branch>`. `worktrees.directory` therefore only governs repos without sibling worktrees.
- herdr refuses new and open worktree actions from a linked worktree. The wrapper resolves the main checkout with `rev-parse --git-common-dir` and passes it as `--cwd`, so the binding works from any worktree.

## Agents sidebar

`ui.sidebar.agents.rows` renders tokens written by two reporters of ours:

- `omp-activity.ts`, deployed to `~/.omp/agent/extensions/herdr-activity.ts`. It skips nested omp sessions via `OMPCODE=1`.
- `claude-activity.py`, deployed to `~/.claude/hooks/herdr-activity.py` and wired into `programs.claude-code.settings.hooks` from `herdr.nix`.

Both report display-only metadata through `pane.report_metadata` and never call `pane.report_agent`. That keeps them clear of the lifecycle state and session identity owned by herdr's own integration.

| Token | Meaning |
| --- | --- |
| `$agent` | Active model, shown only while a turn runs |
| `$title` | Session title |
| `$todo` | Completed count plus the in-progress item; cleared when every task is done |
| `$sub1`..`$sub3` | Running subagents: type and description, one fixed slot per row |
| `$submore` | Overflow subagent types, joined |

Rules both reporters follow:

- Every report carries the full token set. An empty value is how herdr clears a key.
- herdr keys metadata by pane and source, not by process, so tokens outlive their writer until the 12h TTL. Each reporter clears its tokens on shutdown.
- `seq` derives from wall time. A process-local counter would let a newer reporter permanently suppress an older live one in the same pane.
- Values are truncated at 72 characters, under herdr's 80 cap, so the ellipsis is ours.
- Subagent sessions never report their own todo list.

omp specifics: a `task` subagent's `started` event has no description, so the slot updates from `task:subagent:progress`. `$title` follows `sessionManager.onSessionNameChanged`, which covers delayed automatic titles and `/rename`.

Claude specifics (source `user:claude-activity`):

- Hooks are separate processes, so state lives in `~/.claude/herdr-activity/<session_id>.json` under `flock`. Parallel tool calls fire hooks concurrently.
- `$agent` is the `SessionStart` model, shown from `UserPromptSubmit` to `Stop`. `Stop` does not fire on interrupt, so `Notification` `idle_prompt` also hides it.
- Subagent descriptions come from the preceding `PreToolUse` on `Agent`, because `SubagentStart` carries only the type.
- No hook carries the title, so `$title` is the last `ai-title` entry in the transcript. Only the last 1 MiB is read.
- Events with `agent_id` are ignored except the subagent lifecycle.
- `SessionStart` resets state except on `compact`. On `resume` and `fork` it replays todo calls and the title from the transcript. `SessionEnd` clears everything.
- `$todo` needs the task tools, enabled by `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in `claude-code.nix`.

Test the Claude reporter with `python3 modules/programs/herdr/claude-activity.test.py`.

Only the first row is undimmed. The others use explicit muted foregrounds because `dim` alone is not quiet enough. The sidebar is pinned to 36 columns because these rows clip at the default width.

## Notifications

`ui.toast.delivery = "system"` makes the herdr client send a desktop notification (`notify-send` on Linux, shown by DMS) when an agent becomes blocked or finishes a turn. herdr skips it only when the pane's tab is visible and Ghostty has focus. That rule is per tab and not configurable.

## Agent integrations

`herdr.nix` owns these files:

- `~/.omp/agent/extensions/herdr-omp-agent-state.ts`, copied from `${pkgs.herdr.src}/src/integration/assets/omp/herdr-agent-state.ts`. It is the file `herdr integration install omp` writes, so status stays clean. It provides lifecycle state, session identity, and resume. It also listens on the omp event bus channel `herdr:blocked`, which `gate.ts` emits so approval dialogs show as blocked. Never run the installer.
- The herdr skill, at `~/.omp/agent/skills/herdr/SKILL.md` and as `programs.claude-code.skills.herdr`. It is generated from `herdr --skill`, a stable CLI contract that matches the installed binary. Generate it from the flag rather than a path inside `${pkgs.herdr.src}`, whose layout moves between releases.
- Skills shipped by plugins, taken from `mkHerdrPlugin`'s `passthru.skills`, land in `~/.omp/agent/skills/`.

Claude's lifecycle hook is covered in [Coding agents](coding-agents.md).

`agent-shared/_bash.nix` gates every herdr command at `ask` (`"herdr*"` and `"*/herdr*"` in both the jailed and Darwin branches). Keep `pane run`, `pane send-text`, both `send-keys`, and `agent start`/`agent prompt` at `ask`. They type arbitrary input into a live shell or another agent, which would sidestep the whole bash allowlist.

## Plugins

Add a plugin as a `flake = false` input plus one `mkHerdrPlugin` entry in the `plugins` list in `herdr.nix`. Plugin registration stays declarative: leave `herdr plugin install`/`link` and `~/.config/herdr/plugins.json` to the activation script.

```nix
mkHerdrPlugin {
  src = inputs.herdr-plugin-browser;      # flake input with flake = false
  runtimeDeps = [pkgs.bun pkgs.ungoogled-chromium];
  # subdir, build ("auto"|"rust"|"node"|"none"), npmDepsHash, commands, env
}
```

`mkHerdrPlugin` (`_plugins.nix`) reads `herdr-plugin.toml` at eval time, builds with nix, and strips `[[build]]` from the installed manifest. It prefixes every remaining command with a fish wrapper that puts `runtimeDeps` on `PATH`. A wrapper, rather than argv[0] rewriting, is what works when a plugin resolves binaries by name or shells out from its own scripts.

- Build detection: `Cargo.toml` uses `buildRustPackage` with `cargoLock.lockFile`. `package.json` with a `build` script or real dependencies uses `buildNpmPackage` with `importNpmLock`; without `package-lock.json`, `npmDepsHash` is required. Anything else installs source only.
- It asserts `min_herdr_version` against `pkgs.herdr.version` at eval time.
- Activation runs `herdr-plugins-sync`, which reads herdr's `plugins.json` and converges with `herdr plugin link|unlink`. Entries outside `/nix/store` are left alone, so hand-installed plugins survive. A store-path change relinks automatically.
- Only the source-only build is exercised. The rust and node builds are implemented but untested, including how built artifacts reach the paths a manifest expects.

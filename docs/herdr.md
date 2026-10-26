# Herdr reference

Read before changing panes, workspaces, worktrees, helpers, plugins, sidebar telemetry, or agent lifecycle integration. Harness and sandbox details live in [Coding agents](coding-agents.md); editor pane navigation lives in [Neovim](neovim.md#keybinding-philosophy). Source files remain authoritative for current values.

## Herdr

[Herdr](https://herdr.dev) is the terminal multiplexer: `pkgs.herdr` configured through home-manager's `programs.herdr` (no flake input for herdr itself; the package and the module both come from the pinned nixpkgs/home-manager).

### Module layout (`modules/programs/herdr/`)

| File                 | Purpose                                                                                                       |
| -------------------- | ------------------------------------------------------------------------------------------------------------- |
| `herdr.nix`          | aspect `herdr`: `programs.herdr.settings`, the fish helpers, the plugin list, herdr's omp/Claude integrations |
| `_plugins.nix`       | `mkHerdrPlugin` — builds and installs herdr plugins declaratively                                             |
| `nav.fish`           | `herdr-nav <dir>` — vim-aware pane focus                                                                      |
| `resize.fish`        | `herdr-resize <dir>` — pane resize through the CLI                                                            |
| `workspace.fish`     | `herdr-workspace [dir] [label]` — opens a workspace with the default layout                                   |
| `worktree.fish`      | `herdr-worktree [branch]` — creates/reuses the checkout, then opens the workspace                             |
| `plugins-sync.fish`  | converges herdr's plugin registry with the declared set during home-manager activation                        |
| `omp-activity.ts`    | omp extension feeding the Agents sidebar tokens (see Agents sidebar)                                          |
| `claude-activity.py` | the same, as Claude Code hooks                                                                                |

Config is generated from a nix attrset (`settings` → `~/.config/herdr/config.toml`) rather than kept as a static file, because the keybindings interpolate store paths. The home-manager module runs `herdr server reload-config` on change. All helper scripts are fish (`pkgs.writers.writeFishBin`, syntax-checked at build time) with `@herdr@`/`@jq@` substituted for absolute store paths.

**Validate config changes with `herdr config check`** (prints `config: ok` or diagnostics) — far cheaper than a full rebuild when iterating on `settings`. `herdr config reset-keys` backs up `config.toml` and drops custom keybindings if they ever get into a bad state. Note that keybind names are a fixed serde field list (`new_workspace`, `new_worktree`, `open_worktree`, `remove_worktree`, `close_workspace`, `navigate_workspace_up`/`_down`, `focus_pane_*`, `swap_pane_*`, `cycle_pane_*`, `last_pane`, `split_vertical`, `close_pane`, `resize_mode`, `toggle_sidebar`, …); anything absent from it is not bindable, no matter what appears in the changelog.

### Keybindings

| Keys                                   | Action                                              |
| -------------------------------------- | --------------------------------------------------- |
| `ctrl+h/j/k/l`                         | pane focus, vim-aware (via `herdr-nav`)             |
| `ctrl+alt+h/j/k/l`                     | pane resize (via `herdr-resize`)                    |
| `prefix+h/j/k/l`                       | pane focus                                          |
| `prefix+shift+h/j/k/l`                 | swap pane                                           |
| `prefix+v` / `prefix+minus`            | split right / down                                  |
| `prefix+x` / `prefix+shift+x`          | close pane / tab                                    |
| `prefix+z`, `prefix+f`, `alt+m`        | zoom                                                |
| `prefix+c`, `prefix+t`                 | new tab                                             |
| `prefix+n`/`prefix+p`, `alt+]`/`alt+[` | next / previous tab                                 |
| `prefix+1..9`                          | switch to tab                                       |
| `prefix+[`, `prefix+s`                 | copy mode                                           |
| `prefix+e`                             | edit scrollback in `$EDITOR`                        |
| `prefix+r`, `alt+r`                    | resize mode                                         |
| `prefix+w`/`prefix+g`, `alt+w`         | workspace picker / session navigator                |
| `prefix+q`, `alt+d`                    | detach                                              |
| `prefix+shift+t`/`prefix+shift+p`      | rename tab / pane                                   |
| `prefix+shift+s`                       | settings                                            |
| `prefix+shift+l`                       | apply the default layout                            |
| `prefix+shift+g`                       | new worktree (popup, via `herdr-worktree`)          |
| `prefix+alt+g` / `prefix+ctrl+d`       | open / remove worktree                              |
| `prefix+b`, `ctrl+alt+b`               | toggle the sidebar                                  |
| `prefix+ctrl+p` / `prefix+ctrl+n`      | previous / next workspace                           |
| `prefix+shift+1..9`                    | switch to workspace                                 |
| `prefix+a` / `prefix+shift+a`          | next / previous agent                               |
| `prefix+alt+1..9`                      | focus agent                                         |
| `prefix+backtick`                      | last pane (across tabs and workspaces)              |
| `shift+j` / `shift+k`                  | workspace selection **in navigate mode**            |
| `prefix+shift+{n,w,d,r}`, `prefix+?`   | herdr defaults (workspace ops, reload config, help) |

Everything from `prefix+shift+g` down to `shift+j`/`shift+k` is unbound in stock herdr; `navigate_workspace_*` defaulted to arrow keys and moved to the shifted pair because plain `j`/`k` already move panes inside navigate mode. `new_worktree` is explicitly set to `""` (herdr's own spelling for unbound) so `prefix+shift+g` can go to our wrapper, which is the only way to get repo-relative checkouts.

### Layout and persistence

`prefix+shift+l` (or `herdr-workspace [dir] [label]` from any shell) opens one workspace: tab `neovim` = nvim (70%) | omp (30%) (the `@agent@` substitution in `herdr.nix`), tab `terminal` = main (70%) | tooling (30%).

`herdr-workspace` is **ensure**, not create: it looks up the workspace by pane cwd (workspaces do not report a cwd, panes do), creates one only when none matches, and lays out tabs/panes only when the workspace still has nothing but its root pane. So it is safe to re-run, and `herdr-worktree` reuses it by passing the new checkout as `[dir]` plus the branch as `[label]`.

`[label]` names the workspace; passing it also renames an existing one, while the derived default never overrides a name set in the sidebar. The default is `<repo>/<checkout dir>` for a **main** checkout (`integrations-mono/main` rather than a bare `main`, since sibling-worktree layouts would otherwise produce a pile of workspaces all called `main`), collapsing to one segment when the repo name already equals the directory name (`nixos`), and the **bare directory name** for a linked worktree (`async-core-client`) because the sidebar already nests those under their repo. Outside git it is just the directory name. Linked worktrees are detected by `git-dir != git-common-dir`. When `$dir/.envrc` exists it runs `direnv allow` **before** any pane shell starts — otherwise nvim and the agent come up with an untrusted environment. Directories without an `.envrc` are left alone.

### Worktrees

`herdr-worktree [branch]` prompts for the branch when called without one, which is how `prefix+shift+g` uses it (a popup is the only custom command type with a terminal); passing the branch as an argument makes it run unattended from a shell or script. It then makes sure a checkout exists, runs `direnv allow` when that checkout has an `.envrc`, registers it with `herdr worktree open --label <branch> --focus`, and finishes with `herdr-workspace <checkout> <branch>`. So the binding is open-or-create: an existing branch name jumps to its worktree, a new one creates it. The label is the branch alone — the sidebar already nests the workspace under its repo — and it is passed explicitly rather than left to herdr's auto-label, which uses the checkout's directory name and would drop the `feature/` from a slashed branch.

How the checkout is obtained, in order:

| Precondition                                          | Action                                                                          |
| ----------------------------------------------------- | ------------------------------------------------------------------------------- |
| a worktree already exists for `refs/heads/<branch>`   | reuse it, no git mutation (herdr focuses the workspace when it is already open) |
| that checkout is registered but its directory is gone | fail with a `git worktree prune` hint                                           |
| `<repo folder>/<branch>` exists but is not a worktree | fail, distinguishing a leftover directory from git's generic `already exists`   |
| the branch exists locally without a worktree          | `git worktree add <repo folder>/<branch> <branch>` — checked out untouched      |
| the branch does not exist                             | `git worktree add <repo folder>/<branch> -b <branch>` — new branch from HEAD    |

The git calls are made in `worktree.fish` rather than through **`git wa`**, so the wrapper does not break when that alias changes shape — it already did once mid-work, losing its `-B` and with it the ability to create a branch at all (`git worktree add <path> <branch>` treats an unknown branch as a commit-ish and fails with `invalid reference`). The cost is that the path convention (`<repo folder>/<branch>`, raw branch name, no slug) is duplicated from the alias; change it in `git.nix` and `worktree.fish` needs the same edit. After any creation the path is re-read from `git worktree list --porcelain` rather than trusted from the formula.

Two reasons it is a wrapper rather than herdr's built-in `new_worktree`:

- **`worktrees.directory` cannot express the convention.** Checkouts go to `<worktrees.directory>/<repo_name>/<branch-slug>`, and `repo_name` is the *directory name of the repo root* — for `~/dev/integrations-mono/main` that is `main`, so herdr would create `~/dev/main/<branch>`. `worktrees.directory = "~/dev/worktrees"` therefore only governs repos that do not keep worktrees as siblings.
- **herdr refuses worktree actions from a linked worktree** (`linked_worktree_source`: "New and open worktree actions start from the repo parent workspace"). The wrapper resolves the main checkout through `rev-parse --git-common-dir` and passes it as `--cwd`, so the binding works from any worktree of the repo.

The repo half of the label comes from `git remote get-url origin` (basename minus `.git`), falling back to the repo folder's name.

### Agents sidebar

`ui.sidebar.agents.rows` is fed by `omp-activity.ts` (`~/.omp/agent/extensions/herdr-activity.ts`; nested sessions are skipped via `OMPCODE=1`) and Claude's `claude-activity.py` (below). Each reports **display-only** pane metadata through `pane.report_metadata` and never calls `pane.report_agent` — so it cannot disturb the lifecycle state or session identity owned by herdr's own integration sitting next to it.

| Token                     | Meaning                                                | Example                              |
| ------------------------- | ------------------------------------------------------ | ------------------------------------ |
| `$agent`                  | active model, shown only while a turn runs             | `gpt-6.1-sol`                        |
| `$title`                  | session title                                          | `Async core client block_on…`        |
| `$todo`                   | completed count + the in-progress item                 | `1/3 wire the plugin into herdr.nix` |
| `$sub1`, `$sub2`, `$sub3` | running subagents: type + description                  | `explore: audit the bash allowlist`  |
| `$submore`                | the overflow beyond three slots, subagent types joined | `test-writer, tickets`               |

For omp, `$title` subscribes to `sessionManager.onSessionNameChanged`, covering asynchronous automatic titles and idle `/rename` changes. Session navigation replaces the listener; shutdown removes it. Run `node --test modules/programs/herdr/omp-activity.test.mjs` to check delayed titles, renames, and session isolation.

Both reporters refresh `seq` from wall time on every write, retaining a monotonic increment for same-tick reports. A counter based only on process startup lets a newer reporter permanently suppress an older live reporter's updates, including final todo completion. Run `node --test modules/programs/herdr/activity-sequence.test.mjs` for the overlapping-reporter regression.

Both reporters clear `$todo` when every task is completed, hiding the sidebar row rather than showing a final count. Incomplete lists remain visible.

**herdr keys metadata by pane + source, not by process**, so tokens outlive the agent that wrote them until their TTL. omp therefore publishes every token empty on `session_shutdown`; without it a `0/4 …` todo from an omp that quit mid-task sat under the next agent in that pane for 12h.

**Claude Code** has its own reporter, `claude-activity.py` (deployed to `~/.claude/hooks/herdr-activity.py`, wired from `herdr.nix` into `programs.claude-code.settings.hooks`), source `user:claude-activity`. Hooks are separate processes, so it keeps per-session state in `~/.claude/herdr-activity/<session_id>.json` under `flock` (parallel tool calls fire hooks concurrently). `$agent` is the model from `SessionStart`, shown between `UserPromptSubmit` and `Stop`; `$todo` comes from `PostToolUse` on `TaskCreate`/`TaskUpdate`/`TodoWrite`; `$sub*` from `SubagentStart`/`SubagentStop`, with the description taken from the preceding `PreToolUse` on `Agent` (SubagentStart carries only the type). No hook carries the session title, so `$title` is the last `ai-title` entry in the transcript (`transcript_path`; Claude rewrites it every few turns, so only the last 1 MiB is read). `Stop` does not fire on an interrupt, so `Notification` `idle_prompt` also hides `$agent`, a minute later. Events carrying `agent_id` (inside a subagent) are ignored except the subagent lifecycle. `SessionStart` resets, except on `compact`; on `resume`/`fork` it replays the transcript's successful `TaskCreate`/`TaskUpdate`/`TodoWrite` calls (non-sidechain) and title, the counterpart of omp's `todoFromBranch`. `SessionEnd` clears everything. The todo tools are off by default on newer models, hence `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in `claude-code.nix`. Tests: `python3 modules/programs/herdr/claude-activity.test.py`.

`rows` is static, so one subagent per line means one fixed slot per line. Values are pre-truncated at 72 characters (herdr caps at 80) so the ellipsis is ours, every report carries the full token set (an empty value is how herdr clears a key), a monotonic `seq` drops stale writes, and a 12h TTL keeps a `kill -9` from leaving stale lines. Subagent sessions never report their own todo list, so it cannot overwrite yours.

Line one is the only undimmed row, and the rest carry explicit muted foregrounds because `dim` alone is not quiet enough: `#6f8f6b` for `$todo`, `#6c7086` for the subagent slots. `ui.agent_panel_sort = "priority"` floats agents needing attention to the top, and the sidebar is pinned to 36 columns because these rows clip badly at the default 26.

### Notifications

`ui.toast.delivery = "system"`: the herdr client runs `notify-send --app-name Herdr` (DMS shows it; `terminal-notifier`/`osascript` on macOS) when an agent turns `blocked` ("needs attention") or goes working → idle ("finished"). It is skipped only when the pane is in the visible tab **and** Ghostty has focus (or focus is unknown) — per tab, not per pane, and not configurable. `delivery` is one choice, so this replaces the in-herdr toast.

### omp integration

Owned by `herdr.nix`:

- `~/.omp/agent/extensions/herdr-omp-agent-state.ts` ← `${pkgs.herdr.src}/src/integration/assets/omp/herdr-agent-state.ts`, the exact file `herdr integration install omp` writes. Status is clean when it contains `HERDR_INTEGRATION_VERSION>=10`. Gives state, session identity and resume (`omp --resume=<ref>`). It also listens on the omp event bus channel `herdr:blocked`, which the omp `gate.ts` extension emits so its approval dialogs show as `blocked`. Never run the installer.
- `~/.omp/agent/skills/herdr/SKILL.md` ← **`herdr --skill`** (a `runCommand` that pipes the flag's output to `$out`). Teaches agents to drive herdr; self-gates on `HERDR_ENV=1`. Do **not** read this from `${pkgs.herdr.src}`: 0.8 moved the file from the repo root to `skills/herdr/SKILL.md` and the old path broke silently. The CLI flag is a stable contract and guarantees the skill matches the installed binary.
- Skills shipped by plugins, picked up from `mkHerdrPlugin`'s `passthru.skills`, also land in `~/.omp/agent/skills/`.

`agent-shared/_bash.nix` gates every herdr command at `ask` (`"herdr*"` + `"*/herdr*"` in both the jailed and Darwin branches). `pane run`, `pane send-text`, both `send-keys`, and `agent start`/`agent prompt` deliberately stay at `ask`: they type arbitrary input into a live shell — or into another agent — and would sidestep the entire bash allowlist.

### Plugins (`mkHerdrPlugin`)

`herdr plugin install` clones from GitHub and runs the manifest's `[[build]]` commands at install time. Instead, `mkHerdrPlugin` reads `herdr-plugin.toml` at eval time, builds with nix, strips `[[build]]` from the installed manifest, and prefixes every remaining command with a generated fish wrapper that puts `runtimeDeps` on `PATH`. The wrapper (rather than argv[0] rewriting) is what makes dependencies work when a plugin resolves binaries by PATH name or shells out from its own scripts.

```nix
mkHerdrPlugin {
  src = inputs.herdr-plugin-browser;      # flake input with flake = false
  runtimeDeps = [pkgs.bun pkgs.ungoogled-chromium];
  # subdir, build ("auto"|"rust"|"node"|"none"), npmDepsHash, commands, env
}
```

- Build detection: `Cargo.toml` → `buildRustPackage` with `cargoLock.lockFile` (hash-free); `package.json` with a `build` script or real dependencies → `buildNpmPackage` with `importNpmLock` (hash-free when `package-lock.json` exists, otherwise `npmDepsHash` is required — a `bun.lock` alone cannot be fetched without one); anything else → source only.
- Asserts `min_herdr_version` against `pkgs.herdr.version` at eval time.
- Registration: a one-line `home.activation` entry runs `herdr-plugins-sync`, which reads `~/.config/herdr/plugins.json` (herdr's file — we never write it) and converges through `herdr plugin link|unlink`. Entries whose root is not under `/nix/store` are left alone, so hand-installed plugins survive; a store-path change relinks automatically.
- **Unproven paths**: only the source-only strategy is exercised today. The rust and node builds (including how built artifacts are linked back to the paths a manifest expects) are implemented but untested until a plugin needs them.

## Editing guidelines

- **Herdr helpers**: shell helpers are fish, built with `pkgs.writers.writeFishBin` (syntax-checked at build time) and referenced from `settings.keys.command` by absolute store path. Never add a bash/sh helper here.
- **Herdr plugins**: add a `flake = false` input plus one `mkHerdrPlugin` entry in `herdr.nix`; never `herdr plugin install`/`link` by hand, and never write `~/.config/herdr/plugins.json`.

# Herdr reference

Harness and sandbox details live in [Coding agents](coding-agents.md); editor window navigation lives in [Neovim](neovim.md#keybinding-philosophy).

## Installation and configuration

Herdr App and its Core backend come from the `llm-agents` input with no nixpkgs follows. `modules/programs/herdr/herdr.nix` owns both packages and their Home Manager integration. The App is the host desktop client; Core owns terminal processes and saved spaces independently of the window.

Dependencies can substitute from `cache.numtide.com`, configured in `modules/defaults.nix`. Local patches change the App derivation, so the App itself compiles rather than using the upstream cached binary. The Nix daemon reads substituters from its activated configuration or a trusted user. Before cache configuration is activated, root can pass `--option extra-substituters https://cache.numtide.com` with the matching key.

Home Manager owns personal settings, keys, program launcher entries, the theme, the prefix mod and the enriched agents mod. Runtime files remain writable, including `shared.json`, `view.json`, `data/`, `installed.json`, window state and `layouts/.state/`. Rebuilding on another machine restores the declared assets, not terminal sessions or window history.

Before first activation, back up existing unmanaged settings, keys or program files rather than forcing over them. Managed settings reject persistent GUI edits; make those changes in Nix. Transient zoom may still change in memory. Emergency reset can move the keys symlink, requiring a rebuild to restore it.

### Keys and launchers

The Linux key overrides in `herdr.nix` provide direct terminal, split and agent shortcuts. Darwin retains its platform defaults because the corresponding Command chords include copy and zoom actions. The packaged command parser wraps a shorthand executable name in an argv array; without that patch, an agent shortcut falls back to a shell.

The tab-rename override avoids Alt+R, which skim uses, and Super+R, which Hyprland reserves for screen capture. Check terminal-program bindings as well as desktop bindings when choosing App shortcuts.

Terminal-focused Ctrl+H/J/K/L runs the packaged `pane.navigate` command. It sends the chord to Neovim when the App's resolved program identity is `nvim`; other programs use normal pane movement. The native patch stays available independently of sidebar visibility and mod loading. App text fields retain their editing shortcuts.

Neovim hands window-edge movement back with its Core terminal ID. The App ignores that request if the originating terminal no longer has focus, including while a dialog is open. Keep the command patch and the mappings in `configs/lua/utils/keymaps.lua` together when changing this protocol.

The `herdr-tmux-prefix` input contains the upstream examples repository, but only the prefix mod's JavaScript and manifest are installed. Linux uses Super+H to open or dismiss its hint popup, leaving Ctrl+B available to terminal programs. Darwin retains the upstream Ctrl+B behavior. No custom layout or terminal arrangement is installed.

The prefix input follows the upstream default branch. `nix flake update herdr-tmux-prefix` refreshes its locked revision; rebuild afterward to apply it. Source adaptations fail on changed upstream anchors rather than silently dropping behavior.

OMP's launcher entry and agent shortcuts resolve installed command names, including the Linux jail wrappers. Remote spaces require those commands on their target machine; a launcher entry does not install them remotely.

Other modules add launcher entries and global keys through the `herdr.programs` and `herdr.keys` options, because `programs.json` and `keys.json` are single files. An entry with an App built-in name, such as `hermes`, replaces that built-in entry, so restate its icon and colours. The work Hermes uses this for Super+S, which opens the coordinator.

### Tab titles and agent picker

The `herdr-navigation` input owns the Smart Tabs, Agent Picker and Space Shortcuts mods in [their standalone repository](https://github.com/augustocdias/herdr-navigation). Its Home Manager module installs the files; `herdr.nix` connects the packaged main layout and Alt+W to them. Change mod code in that repository, then update the input and rebuild here. The optional community layout is not installed.

Titles are display-only and do not rewrite saved tab names. Descriptive names take precedence; launch defaults such as `shell` and the current program name remain automatic. Session titles prefer the existing activity integration, then native agent reports, then terminal titles. The picker searches full titles even when the visible label is truncated.

The input's key fragment is merged with App defaults before local overrides. Its picker-scoped bindings suppress global Ctrl+1–5 actions while the picker owns focus; without that fragment, Herdr selects tabs or spaces instead of changing filters.

State filters match any agent in a tab rather than only its aggregate status. A tab with both a blocked agent and a working agent therefore appears under either filter. Done follows Herdr's attention semantics and becomes Idle when viewed.

### Package patches and verification

The App regenerates `AGENTS.md` at startup. Its package patches the embedded guide to require declarative additions and a system rebuild. Keep the generated guide App-owned rather than installing a Home Manager symlink. Relaunch the App after activating package patches; restarting Core is not needed to refresh the guide or key-command handling.

The package also exposes `local_layout_ready` in `herdr-app status`. Workspace helpers wait for that flag before listing spaces: the control socket can answer while Core's saved layout is still loading, and treating that early empty list as authoritative creates duplicate spaces.

Check `herdr-app status` for file errors. Validate installed mods with:

```sh
herdr-app check ~/.config/herdr-app/mods/tmux-prefix
herdr-app check ~/.config/herdr-app/mods/agents-enriched
herdr-app check ~/.config/herdr-app/mods/tabs-enriched
herdr-app check ~/.config/herdr-app/mods/picker-enriched
herdr-app check ~/.config/herdr-app/mods/spaces-enriched
herdr-app check ~/.config/herdr-app/mods/space-open
```

`check` needs a compositor and does not prove key handling. Exercise keys in an isolated App/Core session and inspect `herdr-app shot`. Test the Home Manager symlinks, not only an unpacked source copy: App rejects relative JavaScript imports that resolve through those symlinks into the store, so the enriched mod is bundled into one file.

## App sidebar

The packaged main layout uses `agents-enriched`, a copy of the matching upstream agents mod with model, session title, todo progress and internal-worker rows. Stock lifecycle status, attention ordering, focus, pins and real child terminals retain their upstream behavior. Internal workers are informational rows, not terminal targets. Activation copies the stock agents mod's runtime storage once if the enriched mod has none, preserving pins and ordering history.

On Linux, `omp-activity.ts` and `claude-activity.py` send full snapshots through the launcher's `HERDR_ACTIVITY_SOCKET`. The bridge writes only the current terminal's `nix.activity` label. Native OSC reports own lifecycle status; these collectors enrich display metadata only. The model stays visible while idle, and session shutdown clears enrichment.

The bridge holds a per-terminal lock, rejects older session epochs and sequences, and checks terminal identity before writes and cleanup. Its lease expires after 60 seconds without renewal; the renderer checks expiry on its normal refresh. Snapshot age is capped at 12 hours even while the launcher remains alive. OMP sends a collector heartbeat; Claude publishes hook events. The raw host Core socket remains unavailable in the jail.

Collector details that span harness APIs:

- Every snapshot carries the complete token set; empty values clear fields. Nested sessions do not replace root-session metadata.
- OMP worker descriptions arrive after `task:subagent:lifecycle`, through progress events. Session titles follow `sessionManager.onSessionNameChanged`, including automatic titles and `/rename`.
- Claude hooks run in separate processes, so per-session state under `~/.claude/herdr-activity/` uses `flock`. Subagent descriptions come from the preceding `PreToolUse` on `Agent`; `SubagentStart` supplies only the type.
- Claude hooks do not carry session titles. The collector reads the last `ai-title` entry from the final 1 MiB of the transcript. Resume and fork replay task state; compaction preserves it.
- Claude session shutdown retains an ended-session marker so delayed hooks cannot resurrect metadata. Task progress requires `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in `claude-code.nix`.

## Workspaces

`herdr-workspace [dir] [label]` opens or selects a local App space. The directory defaults to the calling shell's cwd. Matching uses the canonical folder and local machine identity, so a remote space with the same path is not reused. Existing tabs and panes remain unchanged; a new space gets the App's normal initial terminal.

The helper starts the App if needed and waits for the local layout to load before selecting or creating a space. When the directory contains `.envrc`, it runs `direnv allow` before opening a terminal there.

An explicit label also renames an existing space. A derived label preserves an existing user-assigned name. Main checkouts use `<repo>/<checkout dir>` unless both names match; linked worktrees and non-Git directories use the directory name. The repo name comes from the `origin` remote basename without `.git`, falling back to the repo folder name.

Helpers are Fish scripts built with `pkgs.writers.writeFishBin`, which syntax-checks them at build time. `mkFish` in `herdr.nix` substitutes command placeholders with store paths. Add helpers through that mechanism.

## Worktrees

`herdr-worktree [branch]` opens or creates a Git worktree from the calling shell's cwd. Without an argument it prompts in that terminal. It resolves the main checkout from Git's common directory, so it also works when called from a linked worktree.

After resolving the checkout, it calls `herdr-workspace <checkout> <branch>`. The explicit label preserves slashes in branch names. Environment trust and App selection belong to the workspace helper.

| Precondition | Action |
| --- | --- |
| A worktree exists for `refs/heads/<branch>` | Reuse it with no Git mutation |
| That worktree is registered but its directory is gone | Fail with a `git worktree prune` hint |
| `<repo folder>/<branch>` exists but is not a worktree | Fail with a specific message |
| The branch exists locally | `git worktree add <repo folder>/<branch> <branch>` |
| The branch does not exist | `git worktree add <repo folder>/<branch> -b <branch>` from HEAD |

After creation, the path is re-read from `git worktree list --porcelain`. The directory convention is shared with `git wa` in `modules/programs/git/git.nix`; change both together. The helper makes its own Git calls rather than depending on that alias.

### Sidebar buttons

The packaged main layout uses `spaces-enriched` from `herdr-navigation`. Its folder and branch buttons beside the local `+` open the `space-open` dialog, a JavaScript port of `herdr-workspace` and `herdr-worktree`: same labels, existing-space matching, worktree preconditions and `<repo folder>/<branch>` convention. The worktree button takes the repository from the active space's first terminal, not a shell cwd. Instead of running `direnv allow` unconditionally, the dialog asks before trusting a folder's own `.envrc` that direnv has not allowed. The buttons act on this computer only.

The port is a copy, not a call into the Fish helpers. A behavior change to either helper or to the `git wa` directory convention needs the same change in `navigation/mods/space-open/main.js` of `herdr-navigation`.

## Agent integrations

The curated `herdr-app` and `herdr-core` skills live under `modules/programs/herdr/skills/`. Both harnesses receive the same directories, including the App skill's mod-development companion. The skills own local workflows; packaged CLI help supplies detailed command reference on demand.

`hc` is installed alongside the App. Linux agent jails reach the user's own Core and App directly, so programs an agent starts through either run on the host; agents are told to start them through jail wrappers. See [Herdr access](coding-agents.md#herdr-access) for the binds and the trade-off. `herdr-app` asks on Darwin. The sidebar-reporting endpoint accepts no general terminal-control commands.

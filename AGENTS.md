# NixOS + nix-darwin Configuration — Dendritic Flake

A fully declarative cross-platform configuration for a single user (`augusto`) spanning two machines: an Intel laptop running NixOS + Hyprland + DankMaterialShell on Wayland, and a Mac mini running macOS via nix-darwin. Managed with the **Den** framework for composable, aspect-based module organization.

> **Keep this file current.** When you change hosts, aspects, module layout, inputs, LSP/formatter/linter sets, OpenCode config, or any documented behavior, update the relevant section of this AGENTS.md in the same change. Treat it as part of the diff, not an afterthought.

## Framework & Module System

### Core stack

| Framework         | Repo                         | Purpose                                                                    |
| ----------------- | ---------------------------- | -------------------------------------------------------------------------- |
| **Den**           | `vic/den`                    | Host/user/aspect composition framework                                     |
| **flake-parts**   | `hercules-ci/flake-parts`    | Modular flake composition                                                  |
| **import-tree**   | `vic/import-tree`            | Recursive auto-discovery of all `.nix` files under `modules/`              |
| **flake-file**    | `vic/flake-file`             | Distributed flake input declarations — each module declares its own inputs |
| **flake-aspects** | `vic/flake-aspects`          | Aspect schema support for Den                                              |
| **home-manager**  | `nix-community/home-manager` | User-level config on both NixOS and Darwin                                 |
| **nix-darwin**    | `nix-darwin/nix-darwin`      | macOS system management for the Mac mini                                   |
| **nix-homebrew**  | `zhaofengli/nix-homebrew`    | Declarative Homebrew (casks) on Darwin                                     |
| **sops-nix**      | `Mic92/sops-nix`             | Secrets management                                                         |

### How it works

1. `import-tree ./modules` discovers every `.nix` file recursively and imports it as a flake-parts module.
1. Each module registers **aspects** via `den.aspects.<name>` and optionally declares flake inputs via `flake-file.inputs.<name>`.
1. `flake.nix` is **auto-generated** — run `nix run .#write-flake` to regenerate it from module declarations.
1. Files prefixed with `_` (e.g., `_plugins.nix`, `_hardware-configuration.nix`) are skipped by import-tree and imported manually where needed.

### Aspects

Aspects are the fundamental composable unit. Each aspect can contain:

- `nixos = { ... }` — NixOS system-level config
- `darwin = { ... }` — nix-darwin (macOS) system-level config
- `homeManager = { ... }` — Home Manager user-level config
- `includes = [ ... ]` — Dependencies on other aspects

Composition chains (one per host):

- **laptop**: `den.hosts.x86_64-linux.laptop` -> `den.aspects.laptop` (hardware) -> `users.augusto` -> `den.aspects.user-linux`
- **macmini**: `den.hosts.aarch64-darwin.macmini` -> `den.aspects.macmini` (hardware) -> `users.augusto` -> `den.aspects.user-macos`

The user aspects are layered: `user-base` (cross-platform aspects that must build on both classes) is included by both `user-linux` (adds Hyprland/DMS/Firefox/work/etc.) and `user-macos` (adds a few Darwin-only packages).

### Conventions

- **Directory-based modules**: `<program>/<program>.nix` (e.g., `git/git.nix`). The aspect name matches the directory name. Anything that depends on more then a single `.nix` file goes into a directory.
- **Single-file modules**: `<program>.nix` directly in `modules/programs/`.
- **`_` prefix**: Helper files not auto-imported (imported manually by their parent module).
- **`nvim-` prefix**: All Neovim plugin flake inputs use this prefix for selective updates via `nix flake update nvim-*`.
- **Nix formatting**: Uses `alejandra` formatter. All Nix code follows its style.
- **Lua formatting**: Uses `stylua` with spaces indentation, single quotes preferred.

## Repository Structure

```
modules/
  defaults.nix              # Global defaults: shared nix settings, GC/optimise, stateVersion (nixos 26.11 / darwin 6)
  dendritic.nix             # Bootstraps den + flake-file
  hosts.nix                 # Host definitions (laptop / macmini)
  inputs.nix                # Core flake inputs (nixpkgs, den, home-manager, sops-nix, darwin, nix-homebrew)
  dev-shells.nix            # devShells.nvim-dev for plugin development
  installer.nix             # Custom NixOS installer ISO

  core/
    disko.nix               # Declarative disk partitioning
    locale.nix              # Timezone (Europe/Berlin), locales (en_US, de_DE, pt_BR)
    users.nix               # User definition (augusto, immutable, fish shell)

  hardware/
    input-devices.nix       # Fingerprint reader (fprintd), touchpad
    networking.nix          # NetworkManager, systemd-resolved, Bluetooth
    laptop/laptop.nix       # NixOS hardware profile: NVMe, Intel GPU, PipeWire, CUPS
    macmini/macmini.nix     # Darwin host: nix-homebrew, Touch ID sudo, system.defaults, EurKEY-Next layout, 1Password, casks

  desktop/
    boot.nix                # GRUB (Catppuccin theme), Plymouth, LUKS/TPM2
    hyprland.nix            # Hyprland Wayland compositor (see Desktop section)
    login-manager.nix       # Pulls in the DMS aspect
    dms.nix                 # DankMaterialShell — full desktop shell (see DMS section)
    yabai-skhd.nix          # macOS tiling WM (yabai) + hotkey daemon (skhd), alt-based hjkl bindings

  packages/
    applications.nix        # GUI apps: Cider, Zed, imv, PeaZip, DrawIO
    cli-tools.nix           # CLI: eza, fd, rg, bat, delta, btop, zoxide, YubiKey tools
    development.nix         # Dev: Node, Python, Ruby, Rust, GCC, LLVM, direnv, AWS CLI
    fonts.nix               # Noto, Fira Code, all Nerd Fonts, Font Awesome

  programs/
    bat/                    # Bat with Catppuccin theme
    firefox/                # Firefox with policy-installed extensions, privacy-hardened
    fish/                   # Fish shell with plugins, aliases, env vars, git abbreviations
    ghostty/                # Ghostty terminal: Catppuccin, 80% opacity, cursor-trail shader
    git/                    # Git: GPG signing, delta pager, extensive aliases
    herdr/                  # Herdr agent multiplexer (see Herdr section)
    mpv.nix                 # MPV with hardware decoding
    neovide/                # Neovide (Neovim GUI)
    neovim/                 # Neovim — extensive config (see Neovim section)
    opencode/               # OpenCode AI assistant (see OpenCode section)
    skim.nix                # Skim fuzzy finder with rg/fd/bat
    starship.nix            # Starship prompt with Catppuccin powerline segments
    stylua.nix              # StyLua config
    thunderbird/            # Thunderbird with extensions
    udiskie.nix             # USB automount
    xdg.nix                 # XDG dirs and MIME associations
    yamllint/               # Yamllint config
    yazi/                   # Yazi file manager with plugins
    zellij/                 # Zellij terminal multiplexer with custom KDL config

  services/
    podman.nix              # Podman with Docker compatibility
    work/
      work.nix              # `work` aspect: aggregates the below + just, awscli2
      datagrip.nix          # JetBrains DataGrip with plugins
      virtualization.nix    # libvirtd/QEMU
      wireguard.nix         # WireGuard tools
      slack.nix             # Slack desktop
      lotion.nix            # Custom Notion desktop client (Electron, AST-patched for SSO)
      teamviewer.nix        # TeamViewer
      sqlit.nix             # sqlit with PostgreSQL support

  security/
    security.nix            # PAM (fingerprint + U2F), TPM2, GPG agent, polkit
    secrets/                # SOPS-nix secrets (API keys, tokens, encrypted env.yaml)

  scripts/
    update-system/          # System update script

  user/
    base.nix                # `user-base` aspect: cross-platform aspects (build on both nixos + darwin)
    linux.nix               # `user-linux` aspect: user-base + Hyprland, DMS login, Firefox, Thunderbird, work, etc.
    mac.nix                 # `user-macos` aspect: user-base + Darwin-only packages (1Password CLI, godot, raycast)
```

## Host Configuration

| Host      | Platform       | hostName  | Status | Description                                                                                         |
| --------- | -------------- | --------- | ------ | --------------------------------------------------------------------------------------------------- |
| `laptop`  | x86_64-linux   | `nixos`   | Active | Intel laptop (Arrow Lake, NPU, Thunderbolt), dual monitor (eDP-1 + DP-1). NixOS + Hyprland + DMS.   |
| `macmini` | aarch64-darwin | `macmini` | Active | Apple Silicon Mac mini. macOS via nix-darwin + nix-homebrew, yabai/skhd tiling, EurKEY-Next layout. |

### macOS (nix-darwin) host — `macmini`

Managed entirely through `modules/hardware/macmini/macmini.nix` (aspect `den.aspects.macmini`, class `darwin`):

- **nix-homebrew**: declarative Homebrew, Rosetta disabled, `cleanup = "zap"` (removes anything not declared). Casks: autodesk-fusion, vlc, blender, orcaslicer, snapmaker-orca, mac-mouse-fix, freecad.
- **Auth**: Touch ID for `sudo` (`security.pam.services.sudo_local.touchIdAuth`).
- **system.defaults**: dark mode, show-all-extensions/files, fast key repeat, disabled autocorrect/substitutions, dock autohide, Finder list view + path/status bar, screenshots to `~/pictures/screenshots`, trackpad tap-to-click + three-finger drag, Spotlight hotkeys disabled.
- **Keyboard**: CapsLock -> Control; **EurKEY-Next** layout bundle built from the `eurkey-next` flake input and installed to `/Library/Keyboard Layouts/` via a post-activation script.
- **Window management**: `yabai-skhd` aspect (bsp layout, 8px gaps/padding, `alt`-based hjkl focus/swap/resize, `alt+1..9` spaces, `alt+return` Ghostty, `alt+b` 1Password). yabai scripting addition enabled.
- **Other**: 1Password GUI, fish as login shell.

## Desktop Environment

### Hyprland

Wayland tiling compositor with:

- **Layout**: dwindle (default) + scrolling workspace (plugin)
- **Monitors**: eDP-1 (laptop, workspaces 1-5) + DP-1 (external, workspaces 6-10)
- **Keybindings**: `SUPER` as main modifier. All directional bindings use hjkl (no arrow keys).
- **Auto-start**: Slack, Thunderbird, Firefox, Ghostty, DataGrip (assigned to specific workspaces). The Ghostty window starts a plain shell; the multiplexer is launched by hand.
- **Window rules**: Float dialogs, PiP, file pickers. Size constraints for various apps.

### DankMaterialShell (DMS)

DMS is a **comprehensive Wayland desktop shell** built on [Quickshell](https://git.outfoxxed.me/quickshell/quickshell) (Qt/QML). It replaces the entire typical Wayland desktop toolkit stack:

| DMS replaces      | Traditional tool           |
| ----------------- | -------------------------- |
| Top bar/panel     | Waybar, Polybar            |
| App launcher      | Rofi, Wofi, Fuzzel         |
| Lock screen       | Swaylock, Hyprlock         |
| Login greeter     | greetd + tuigreet/gtkgreet |
| Notifications     | dunst, mako                |
| Clipboard manager | cliphist, clipman          |
| Screenshot tool   | grim + slurp               |
| Screen recorder   | wf-recorder                |
| Idle management   | swayidle, hypridle         |
| Power menu        | wlogout                    |
| System tray       | (built-in)                 |

#### Architecture

DMS runs as a **systemd user service** and communicates with Hyprland through:

- **IPC**: `dms ipc call <target> <method>` (e.g., `dms ipc call launcher toggle`)
- **CLI**: `dms screenshot [full] [--no-file] [--no-clipboard] [-d <dir>]`
- **Hyprland keybindings** that invoke `dms` commands (SUPER+SPACE for launcher, SUPER+SHIFT+L for lock, etc.)

#### Key IPC commands

| Command                                      | Action           |
| -------------------------------------------- | ---------------- |
| `dms ipc call launcher toggle`               | App launcher     |
| `dms ipc call powermenu toggle`              | Power menu       |
| `dms ipc call lock lock`                     | Lock screen      |
| `dms ipc call plugins toggle aiAssistant`    | AI assistant     |
| `dms ipc call screenRecorder startRecording` | Screen recording |
| `dms ipc call screenRecorder stopRecording`  | Stop recording   |
| `dms ipc call mpris playPause/previous/next` | Media control    |

#### Features configured in this repo

- **Bar**: top position, 50% transparency, Catppuccin theme, widgets: launcher, workspaces, window title, apps, MPRIS, clock, weather, tray, recorder, notifications, clipboard, CPU/RAM/battery, control center, session power
- **Launcher**: list view, compact, recent-first sorting, DuckDuckGo web search, emoji (`:` trigger), calculator
- **Lock screen**: password + fingerprint + FIDO2/U2F parallel auth, video wallpaper from `~/media/animated/`
- **Greeter**: the greeter now ships as a **separate flake** (`AvengeMedia/dank-greeter`, input `dank-greeter`), driven by `programs.dms-greeter` (Hyprland compositor). It syncs the user's DMS theme/wallpaper/settings into its cache dir `/var/lib/dms-greeter` (copied from `~/.config/DankMaterialShell/` etc. via `configHome`) before greetd starts.
- **Control center**: volume, brightness, WiFi, Bluetooth, audio I/O, DND, idle inhibitor, VPN, KDE Connect
- **Notifications**: 5s timeout (normal), persistent (critical), 50 history items, 7-day retention
- **Desktop widgets**: system monitor (CPU/RAM/network/disk) + weather forecast
- **Wallpaper**: cycling every 300s from `~/media/wallpapers/`
- **Power management**: AC: 10min screen off, 3min lock, 30min suspend. Battery: power-saver profile, 20min suspend.
- **Dynamic theming**: not enabled. only active to make dank set colors for gtk and qt apps.
- **Plugins**: dankBatteryAlerts, dankKDEConnect, dankHyprlandWindows, dankDesktopWeather, displaySettings, developerUtilities, wallpaperCarousel, sessionPower, aiAssistant (Anthropic Claude)
- **AI assistant**: built-in, uses Anthropic Claude Opus 4

#### DMS Nix structure

- Greeter (`dank-greeter` flake input, `nixosModules.default` → `programs.dms-greeter`): greetd-based greeter with Hyprland as compositor, cache dir `/var/lib/dms-greeter`. Lives in its own repo now, not the DMS flake.
- Home Manager module (`homeModules.dank-material-shell`): 700+ lines of declarative config
- Plugin registry: separate flake input (`dms-plugins`)
- SOPS secrets injected via systemd environment file at `%t/dms-env`

## Herdr

[Herdr](https://herdr.dev) is an agent-aware terminal multiplexer: `pkgs.herdr` configured through home-manager's `programs.herdr` (no flake input for herdr itself; the package and the module both come from the pinned nixpkgs/home-manager). It currently runs **alongside zellij** — both aspects sit in `user-base`, and Neovim/OpenCode detect at runtime which one they are inside.

### Module layout (`modules/programs/herdr/`)

| File                   | Purpose                                                                                                        |
| ---------------------- | -------------------------------------------------------------------------------------------------------------- |
| `herdr.nix`            | aspect `herdr`: `programs.herdr.settings`, the fish helpers, the plugin list, herdr's own OpenCode integration |
| `_plugins.nix`         | `mkHerdrPlugin` — builds and installs herdr plugins declaratively                                              |
| `nav.fish`             | `herdr-nav <dir>` — vim-aware pane focus                                                                       |
| `resize.fish`          | `herdr-resize <dir>` — pane resize through the CLI                                                             |
| `workspace.fish`       | `herdr-workspace [dir] [label]` — opens a workspace with the default layout                                    |
| `worktree.fish`        | `herdr-worktree [branch]` — creates/reuses the checkout, then opens the workspace                              |
| `plugins-sync.fish`    | converges herdr's plugin registry with the declared set during home-manager activation                         |
| `opencode-activity.js` | OpenCode plugin feeding the Agents sidebar tokens (see Agents sidebar)                                         |

Config is generated from a nix attrset (`settings` → `~/.config/herdr/config.toml`) rather than kept as a static file like `zellij/config.kdl`, because the keybindings interpolate store paths. The home-manager module runs `herdr server reload-config` on change. All helper scripts are fish (`pkgs.writers.writeFishBin`, syntax-checked at build time) with `@herdr@`/`@jq@` substituted for absolute store paths.

Non-key settings: `theme.name = "catppuccin"`, `ui.pane_borders = false` (matching zellij's `pane_frames false`), `ui.copy_on_select`, `ui.sound.enabled = false`, `ui.toast.delivery = "system"` (agent notifications go to the OS notification service, i.e. DMS on the laptop, instead of an in-app toast), `session.resume_agents_on_restore`, `experimental.kitty_graphics` (required by the browser plugin), `onboarding = false`.

### Keybindings

Herdr has a tmux-style one-shot prefix — `ctrl+g` here, mirroring zellij's mode key — plus direct chords. There is no locked mode and no modal submodes, so nothing like `zellij-autolock` is needed: unbound keys always reach the pane.

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

`ctrl+alt+h/j/k/l` and `alt+r` are why `yabai-skhd.nix` puts yabai's window resize, space balance and bsp layout on `ctrl+cmd` instead.

Gaps versus the zellij setup, all inherent to herdr: no split left/up, no direct resize *action* (only resize mode, hence the CLI helper), no stacked panes, and no responsive layout swapping (`wide.kdl` has no equivalent).

### Layout and persistence

`prefix+shift+l` (or `herdr-workspace [dir] [label]` from any shell) opens one workspace: tab `neovim` = nvim (70%) | opencode (30%), tab `terminal` = main (70%) | tooling (30%).

`herdr-workspace` is **ensure**, not create: it looks up the workspace by pane cwd (workspaces do not report a cwd, panes do), creates one only when none matches, and lays out tabs/panes only when the workspace still has nothing but its root pane. So it is safe to re-run, and `herdr-worktree` reuses it by passing the new checkout as `[dir]` plus the branch as `[label]`.

`[label]` names the workspace; passing it also renames an existing one, while the derived default never overrides a name set in the sidebar. The default is `<repo>/<checkout dir>` for a **main** checkout (`integrations-mono/main` rather than a bare `main`, since sibling-worktree layouts would otherwise produce a pile of workspaces all called `main`), collapsing to one segment when the repo name already equals the directory name (`nixos`), and the **bare directory name** for a linked worktree (`async-core-client`) because the sidebar already nests those under their repo. Outside git it is just the directory name. Linked worktrees are detected by `git-dir != git-common-dir`. When `$dir/.envrc` exists it runs `direnv allow` **before** any pane shell starts — otherwise nvim and opencode come up with an untrusted environment. Directories without an `.envrc` are left alone.

Herdr has **no layout files**. Panes are always interactive shells — `pane split`/`tab create` accept no argv and `pane run` types into the shell — so killing nvim or opencode drops back to a prompt and the pane survives, unlike zellij's `command` panes. Recreating a session is herdr's own job: snapshot restore rebuilds workspaces/tabs/panes/cwd/focus after a server restart, and with `session.resume_agents_on_restore` the OpenCode pane resumes its conversation (`opencode --session <id>`) via the integration below.

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

`ui.sidebar.agents.rows` is fed by `opencode-activity.js` (deployed to `~/.config/opencode/plugins/herdr-activity.js`), which reports **display-only** pane metadata through `pane.report_metadata` and never calls `pane.report_agent` — so it cannot disturb the lifecycle state or session identity owned by herdr's own integration sitting next to it.

| Token                     | OpenCode event → field                                                               | Example                              |
| ------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------ |
| `$agent`                  | `chat.message` → `input.agent`, cleared on `session.idle`                            | `build`                              |
| `$title`                  | `session.updated` → `info.title`, minus OpenCode's `New session - <iso>` placeholder | `Async core client block_on…`        |
| `$todo`                   | `todo.updated` → completed count + the `in_progress` item                            | `1/3 wire the plugin into herdr.nix` |
| `$sub1`, `$sub2`, `$sub3` | `tool.execute.before` where `tool == "task"` → `subagent_type` + `description`       | `explore: find zellij couplings`     |
| `$submore`                | the overflow beyond three slots, subagent types joined by `, `                       | `test-writer, tickets`               |

`rows` is static, so one subagent per line means one fixed slot per line. Values are pre-truncated at 72 characters (herdr caps at 80) so the ellipsis is ours, every report carries the full token set (an empty value is how herdr clears a key), a monotonic `seq` drops stale writes, and a 12h TTL keeps a `kill -9` from leaving stale lines. Events from sessions with a `parentID` are dropped, so a subagent's todo list can never overwrite yours; the `$subN` slots come from the parent's own `task` tool calls and each clears when its `callID` finishes. `$agent` clears on `session.idle`, because `Tab` cycles the agent purely inside the TUI (`local.agent.move` writes an in-memory store, with no bus event, no persistence and no `agent` field in the plugin's `TuiState` view) — an idle pane would otherwise keep showing whichever agent last sent a message.

Line one is the only undimmed row, and the rest carry explicit muted foregrounds because `dim` alone is not quiet enough: `#6f8f6b` for `$todo`, `#6c7086` for the subagent slots. `ui.agent_panel_sort = "priority"` floats agents needing attention to the top, and the sidebar is pinned to 36 columns because these rows clip badly at the default 26.

### OpenCode integration and skills

`herdr.nix` owns these (not `opencode.nix` — herdr's integration is herdr's business):

- `~/.config/opencode/plugins/herdr-agent-state.js` ← `${pkgs.herdr.src}/src/integration/assets/opencode/herdr-agent-state.js`. Reports lifecycle state and session identity, which is what makes the sidebar show `working`/`blocked`/`idle` and makes agent panes resumable. Deployed from the same source revision as the binary, so it can never skew — never run `herdr integration install opencode`.
- `~/.config/opencode/skills/herdr/SKILL.md` ← `${pkgs.herdr.src}/SKILL.md`. Teaches agents to drive herdr; self-gates on `HERDR_ENV=1`.
- Skills shipped by plugins, picked up from `mkHerdrPlugin`'s `passthru.skills`.

`opencode.nix` allows herdr inspection and topology in `readOnlyBash` (`pane list/get/read/split/focus/resize`, `tab create`, `agent wait`, …). `pane run`, `pane send-text`, both `send-keys`, and `agent start`/`agent prompt` deliberately stay at `ask`: they type arbitrary input into a live shell — or into another agent — and would sidestep the entire bash allowlist.

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

Installed: `official.browser` (`ogulcancelik/herdr-browser`) — Linux only, drives a headless Chromium in a pane over CDP, needs `bun` + `ungoogled-chromium` on `PATH` and `experimental.kitty_graphics = true`.

## Neovim

### Architecture

- **Nightly build** via `neovim-nightly-overlay` (currently pinned to Apr 9 2025 due to nixpkgs wrapper.nix bug — see FIXME in neovim.nix)
- **50+ plugins** managed as flake inputs with `nvim-` prefix and built with nix
- **Plugin loader**: `lze` (BirdeeHub/lze) — lazy.nvim alternative focused only on lazy loading instead of package management
- **Config location**: `modules/programs/neovim/configs/` symlinked to `~/.config/nvim` via `mkOutOfStoreSymlink` for live editing without rebuild
- **Plugin build**: `_plugins.nix` provides `buildPlugin` with three strategies: source-only (most plugins), flake package (lze, blink-cmp, rustaceanvim), custom Rust build (codesnap)

### Plugin management

Two helper functions declare flake inputs:

- `mkPlugin "github:author/repo"` — source-only (`flake = false`), built via `vimUtils.buildVimPlugin`
- `mkFlakePlugin "github:author/repo"` — full flake, uses pre-built `packages.${system}.default`

To update all neovim plugins: `nix flake update nvim-*` or run the `update-nvim` script.

### LSP servers

| Server        | Language      | Notes                                                                                  |
| ------------- | ------------- | -------------------------------------------------------------------------------------- |
| rust-analyzer | Rust          | Via rustaceanvim, clippy on save, nightly rustfmt                                      |
| tsgo          | TypeScript/JS | Go-based native LSP (typescript-go package), formatting disabled (prettier handles it) |
| nixd          | Nix           |                                                                                        |
| emmylua_ls    | Lua           | Workspace includes all plugin paths                                                    |
| bashls        | Bash          |                                                                                        |
| yamlls        | YAML          | SchemaStore integration                                                                |
| jsonls        | JSON          | SchemaStore integration                                                                |
| eslint        | JS/TS         | Also used as linter                                                                    |
| taplo         | TOML          |                                                                                        |
| harper_ls     | Grammar       | Checks prose in comments                                                               |
| docker LSPs   | Docker        | dockerfile + compose                                                                   |
| qmlls         | QML           | For Quickshell/DMS development                                                         |
| gdscript      | GDScript      | Godot engine                                                                           |

### Formatters (conform.nvim)

CSS/HTML/JS/TS/JSON/YAML: prettier | Lua: stylua | Nix: alejandra | Python: black | Shell: shfmt | SQL: sqlfluff | Markdown: markdownlint | Rust: rustfmt (via rust-analyzer, nightly)

### Linters (nvim-lint)

Dockerfile: hadolint | JS/TS: eslint | Lua: selene | Markdown: markdownlint + write_good + codespell | Nix: statix + deadnix | YAML: yamllint + actionlint

### Keybinding philosophy

- **Leader**: Space. **Local leader**: `\`
- **Vim-centric**: modal editing, motions enhanced (flash, treesitter textobjects)
- **Mnemonic groups**: `<leader>l` LSP, `<leader>g` Git, `<leader>h` Gitsigns, `<leader>r` Rust, `<leader>t` Trouble, `<leader>p` search/grep, `<leader>v` Vim internals, `<leader>a` AI
- **Multiplexer integration**: `<C-h/j/k/l>` moves between Neovim splits and falls through to herdr or Zellij panes at edges. Hand-rolled in `utils/keymaps.lua` (`mux_move`), not a plugin: it runs `wincmd <dir>` and, when the window did not change, dispatches on the environment — `HERDR_PANE_ID` → `herdr pane focus --direction`, `ZELLIJ` → `zellij action move-focus`, neither → no-op.
- **No arrow key dependency**: `<C-h/j/k/l>` provides cursor movement in insert/command mode
- **Clipboard isolation**: system clipboard NOT synced by default; `<leader>c` in visual mode copies explicitly

### AI integration

OpenCode TUI (vim fork) runs standalone alongside neovim, connected via nvim-mcp:

- **Vim mode**: Full modal editing in the TUI prompt input (hjkl, w/b/e, dd, cw, yy, p, u, visual mode)
- **nvim-mcp**: MCP server connecting OpenCode to the running neovim instance via msgpack-RPC socket. Gives OpenCode access to open buffers, cursor position, diagnostics, selections, and in-buffer editing with full undo support.
- **Socket discovery**: Neovim creates a socket at `~/.cache/nvim/server-<suffix>.pipe`, where the suffix is `HERDR_WORKSPACE_ID`, else `ZELLIJ_SESSION_NAME`, else `dettached`. The nvim-mcp wrapper resolves the same chain at runtime, so an OpenCode pane reaches the Neovim instance of its own herdr workspace (or zellij session).
- **Global instructions**: Personal coding style preferences in `~/.config/opencode/AGENTS.md` (managed via `programs.opencode.context`), applied to all projects alongside project-level AGENTS.md files.

### Notable custom features

- **Plugin Update Checker** (`plugin-updates.lua`): 569-line module that parses `flake.lock`, queries GitHub for each `nvim-*` input, shows a live-updating dashboard with commit diffs at startup
- **Gatekeeper** (`augustocdias/gatekeeper.nvim`): author's own plugin that makes buffers outside CWD readonly
- **Treesitter-aware fold text**: custom fold rendering preserving syntax highlighting
- **Dual theme support**: Catppuccin (default) and Tokyo Night, switchable via one line in `init.lua`

## OpenCode

### Configuration (`modules/programs/opencode/opencode.nix`)

- **Model**: `anthropic/claude-opus-4-8` (Opus everywhere, including subagents)
- **Default agent**: `plan`
- **TUI theme**: `catppuccin-macchiato`
- **Other settings**: `autoupdate = false`, `lsp = false`; anthropic + openai providers keyed from env (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`).

### Agents (`modules/programs/opencode/agents/*.md` → `~/.config/opencode/agent/`)

Agent markdown files carry `description` + `mode` + prompt; **permissions are owned by nix** in `opencode.nix` (`settings.agent.<name>.permission`). Agent permissions merge with and override the global `permission` block, so the primaries re-apply the shared `let` fragments (`readOnlyBash`, `ghCustomTools`, `denyDatadog`, `denyTicketWrites`, `primaryBase`) explicitly — otherwise a built-in agent's own ruleset would stomp the global bash whitelist.

**Tool gating = context debloat.** A `"*": "deny"` rule removes the tool from the model's schema entirely (verified via `Permission.visibleTools`), so denying an MCP's tools on the primaries strips those definitions from every session; they reappear only inside the subagent that needs them.

| Agent          | Mode              | Role                                                                                                                                                   | Notable permissions                                                                                                                                                           |
| -------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `build`        | primary           | Full development (unchanged)                                                                                                                           | `edit: allow`; `datadog_*` + ticket writes denied                                                                                                                             |
| `plan`         | primary (default) | Read-only analysis/planning                                                                                                                            | `edit: deny`; gh/ticket writes + `datadog_*` denied                                                                                                                           |
| `pair`         | primary           | Read-only pairing companion — annotates the editor (highlights/virtual text) but never edits                                                           | `edit: deny`; mutating nvim tools (`nvim_find_and_replace_buf`, `nvim_write_full_buf`, `nvim_send_keys`) denied, `nvim_send_command: ask`; read/annotation nvim tools allowed |
| `reviewer`     | subagent          | Pre-commit/PR code review                                                                                                                              | `edit: deny`; read-only git bash + `gh_*_read`                                                                                                                                |
| `troubleshoot` | subagent          | Incident/issue investigation via Datadog (only agent with `datadog_*` enabled). Prompt encodes skill-discovery-first + logs→traces→metrics methodology | `datadog_*: allow`; `edit: deny`                                                                                                                                              |
| `tickets`      | subagent          | Linear/Notion triage, spec writing, status updates                                                                                                     | reads allowed; `linear_*`/`Notion_*` writes `ask`                                                                                                                             |
| `test-writer`  | subagent          | Writes tests only; prompt forbids editing implementation                                                                                               | `edit: ask` (build-tier)                                                                                                                                                      |

### Commands (`modules/programs/opencode/commands/*.md` → `~/.config/opencode/command/`)

Markdown command templates using `!` `` `cmd` `` shell injection and `$ARGUMENTS`.

| Command   | Agent              | Purpose                                                                                              |
| --------- | ------------------ | ---------------------------------------------------------------------------------------------------- |
| `/commit` | build              | Drafts a conventional commit message from `git diff --cached`, commits after approval (never pushes) |
| `/pr`     | build              | Drafts a PR description from the branch diff, opens via `gh_pr_write` after approval                 |
| `/review` | reviewer (subtask) | Delegates the current diff/branch/PR to the `reviewer` subagent                                      |

Both agents and commands are plain markdown, so they deploy via `xdg.configFile` **symlinks** (the Bun symlink issue only affects the `.ts` custom tools). The loader scans both `agent/`+`agents/` and `command/`+`commands/`.

### MCP servers

Always available:

| Server   | Type                                        | Purpose                                                                                               |
| -------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Context7 | local (`@upstash/context7-mcp`)             | Library documentation (64k min tokens)                                                                |
| nvim     | local (nix run `nvim-mcp` wrapper)          | Neovim instance access via msgpack-RPC (auto-connects to the herdr workspace / zellij session socket) |
| nixos    | local (nix run `github:utensils/mcp-nixos`) | nixpkgs / NixOS / HM / darwin option + package lookup                                                 |

Linux-only (gated via `lib.optionalAttrs (!isDarwin)` — not present on the Mac mini):

| Server  | Type                   | Purpose                  |
| ------- | ---------------------- | ------------------------ |
| Notion  | remote                 | Notion workspace access  |
| linear  | local (npx mcp-remote) | Issue tracking           |
| datadog | remote (EU endpoint)   | Observability/monitoring |

### Custom tools (deployed to `~/.config/opencode/tools/`)

Tools are TypeScript files using `@opencode-ai/plugin` SDK, executing shell commands via `Bun.$`. Deployed via `home.activation` (cp, not symlink) due to Bun module resolution issue with Nix store symlinks (tracked: <https://github.com/anomalyco/opencode/issues/5914>).

| Tool file            | Exports                     | Purpose                                                                 |
| -------------------- | --------------------------- | ----------------------------------------------------------------------- |
| `date.ts`            | `date`                      | Date arithmetic via Unix `date` command                                 |
| `gh.ts`              | 12 tools (read/write split) | GitHub CLI wrapper: issues, PRs, workflows, runs, search, status, repos |
| `google_calendar.ts` | `google_calendar`           | Read-only Google Calendar via `gcalcli`                                 |

### Bash permission philosophy

**Default-deny, explicit-allow with read/write split:**

- `"*" = "ask"` — global default, all unknown commands require approval
- Read-only commands auto-allowed: git inspection, file reading (`cat`, `ls`, `bat`), search (`rg`, `fd`, `grep`, `find`), text processing (`jq`, `yq`, `cut`, `tr`), system info, network inspection (`curl`, `dig`), language toolchains (cargo, node, nix), gh CLI reads, herdr inspection
- **Commands that can execute or write are deliberately absent from the allowlist**, because they defeat every deny rule below: `env` (runs whatever follows it), `awk` (`system()`, `print | "sh"`), `sed` (`e` runs shell commands, `w` writes files, and `-i` still matches a `sed -n*` pattern — all three verified), `sort` (`--compress-program`). They fall through to `"*" = "ask"`. `find` stays allowed, with `-exec`/`-ok`/`-delete`/`-fprintf` pulled back to `ask`.
- All mutations require approval: file writes, git commits/push, package installs, gh writes
- Custom tools: `*_read` tools are `"allow"`, `*_write` tools are `"ask"`
- **The whitelist is factored into a `readOnlyBash` `let` binding and applied per-agent.** Agent permissions override the global block, so a built-in agent (e.g. `plan`) would otherwise reset `bash` to `ask` and ignore the global allows — every agent that should run read-only bash re-applies `readOnlyBash` explicitly.
- **Matching semantics** (verified empirically against opencode 1.18.4): each pattern is a glob matched against a whole command segment, anchored `^…$`, with `*`→`.*` and `?`→`.`; a pattern ending in `" *"` also matches the bare command. So `"cat*"` covers `cat`, `cat x`, `cat -n x`. Rules are evaluated with `findLast` over **JSON key order**, and nix emits attrset keys in byte order, so the **lexicographically last matching pattern wins**. This is not the same as "most specific wins", and it has two consequences worth internalising:
  - A `"*"`-prefixed pattern sorts before everything (`*` is 0x2A) and is therefore the **weakest** rule, not the strongest. `"*nixos-rebuild*" = "deny"` loses to any letter-prefixed allow that matches the same segment.
  - To beat an allow with a narrower rule, the narrower pattern must **share the allow's prefix and be longer** — `"find*-exec*"` beats `"find*"`, while `"find -exec*"` would lose, because space (0x20) sorts before `*`.
  - Probe it after any change: `nix build --version` must be denied and `env nix build --version` must not print a version.
- **Pipelines are all-or-nothing**: a piped/`&&`-chained command needs approval if *any* single segment resolves to `ask`. Env-assignment or `timeout`/`git -C` prefixes defeat a plain whitelist entry (they change the segment), so `readOnlyBash` includes transparent-prefix patterns (`"*=* cargo *"`, `"timeout * cargo *"`, `"git -C * log*"`, …). These require a real prefix (`=` or literal `timeout`/`git -C`), so `sudo cargo …` still asks.

## Security Model

- **Disk encryption**: LUKS with TPM2 auto-unlock + FIDO2 backup
- **Authentication**: PAM with fingerprint (fprintd) + U2F (YubiKey) as `sufficient` alternatives
- **Secrets**: sops-nix with age (per-machine key) + GPG (YubiKey master key)
- **GPG**: YubiKey-backed key for git signing, SSH auth (gpg-agent), password store, sops decryption
- **Immutable users**: `users.mutableUsers = false`

## Theming

The entire system uses **Catppuccin Mocha**:

- GRUB, Plymouth, Hyprland, DMS, Ghostty, Neovim, Firefox, bat, delta, starship, skim, yazi, zellij, herdr
- Cursors: catppuccin-mocha-blue-cursors
- GTK/Qt: synced via DMS Matugen templates
- Monospace font: MonaspiceNe Nerd Font (terminal), MonaspiceRn Nerd Font (italic)
- Proportional font: Inter Variable (DMS)

## Common Operations

```bash
# Rebuild NixOS (laptop)
sudo nixos-rebuild switch --flake .

# Rebuild macOS (macmini)
darwin-rebuild switch --flake .

# Regenerate flake.nix after changing module inputs
nix run .#write-flake

# Update all neovim plugins
nix flake update nvim-*
# or use the wrapper script:
update-nvim

# Update system packages
update-system

# Update Firefox/Thunderbird extensions
update-firefox
update-thunderbird

# Dev shell for neovim plugin development
nix develop .#nvim-dev

# Update herdr plugin sources (herdr itself follows nixpkgs)
nix flake update herdr-plugin-browser

# Open (or create) a herdr workspace with the default layout
herdr-workspace                                    # current directory
herdr-workspace ~/dev/integrations-mono/main       # label defaults to integrations-mono/main
herdr-workspace ~/dev/some-repo my-name            # explicit workspace name
```

## Editing Guidelines

- **Use the `nixos` MCP** when working with anything Nix: look up package names/attributes, verify NixOS / home-manager / nix-darwin option names and types, check flake inputs, or confirm a package exists in a channel — before writing or changing config. Your training data lags nixpkgs, so prefer it over guessing option/package names. It can also **read the Nix store directly** (`action: store` with `type: ls` or `type: read` on a `/nix/store/...` path) — use it to inspect a built derivation's contents, wrappers, `nix-support/` metadata, or config files without shelling out.
- **Nix files**: Format with `alejandra`. Follow `den.aspects` pattern for new modules.
- **Lua files**: Format with `stylua`. Follow `plugins/<name>.lua` pattern for new plugin configs. Use `lze` spec format (event, cmd, keys, ft for lazy loading).
- **KDL files** (zellij): All directional bindings use hjkl, no arrow keys.
- **Herdr helpers**: shell helpers are fish, built with `pkgs.writers.writeFishBin` (syntax-checked at build time) and referenced from `settings.keys.command` by absolute store path. Never add a bash/sh helper here.
- **Herdr plugins**: add a `flake = false` input plus one `mkHerdrPlugin` entry in `herdr.nix`; never `herdr plugin install`/`link` by hand, and never write `~/.config/herdr/plugins.json`.
- **Hyprland config**: All directional bindings use hjkl, no arrow keys. `$mainMod` is SUPER.
- **macOS (nix-darwin)**: New Darwin config goes in a `darwin = { ... }` aspect block. yabai/skhd bindings use hjkl with `alt` as the modifier (no arrow keys). Homebrew casks are declared in `macmini.nix` (`cleanup = "zap"` removes undeclared ones).
- **OpenCode tools**: TypeScript using `@opencode-ai/plugin` SDK. Deploy via `home.activation` copy (not xdg.configFile symlink).
- **Secrets**: Never commit plaintext secrets. All secrets go through sops-nix. API keys are in `modules/security/secrets/env.yaml`.
- **Flake inputs**: Declare per-module using `flake-file.inputs`, not in `flake.nix` directly.

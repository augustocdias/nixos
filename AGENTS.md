# NixOS + nix-darwin Configuration — Dendritic Flake

A fully declarative cross-platform configuration for a single user (`augusto`) spanning two machines: an Intel laptop running NixOS + Hyprland + DankMaterialShell on Wayland, and a Mac mini running macOS via nix-darwin. Managed with the **Den** framework for composable, aspect-based module organization.

> **Keep this file current.** When you change hosts, aspects, module layout, inputs, LSP/formatter/linter sets, OpenCode config, or any documented behavior, update the relevant section of this AGENTS.md in the same change. Treat it as part of the diff, not an afterthought.

## Framework & Module System

### Core stack

| Framework | Repo | Purpose |
|-----------|------|---------|
| **Den** | `vic/den` | Host/user/aspect composition framework |
| **flake-parts** | `hercules-ci/flake-parts` | Modular flake composition |
| **import-tree** | `vic/import-tree` | Recursive auto-discovery of all `.nix` files under `modules/` |
| **flake-file** | `vic/flake-file` | Distributed flake input declarations — each module declares its own inputs |
| **flake-aspects** | `vic/flake-aspects` | Aspect schema support for Den |
| **home-manager** | `nix-community/home-manager` | User-level config on both NixOS and Darwin |
| **nix-darwin** | `nix-darwin/nix-darwin` | macOS system management for the Mac mini |
| **nix-homebrew** | `zhaofengli/nix-homebrew` | Declarative Homebrew (casks) on Darwin |
| **sops-nix** | `Mic92/sops-nix` | Secrets management |

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

| Host | Platform | hostName | Status | Description |
|------|----------|----------|--------|-------------|
| `laptop` | x86_64-linux | `nixos` | Active | Intel laptop (Arrow Lake, NPU, Thunderbolt), dual monitor (eDP-1 + DP-1). NixOS + Hyprland + DMS. |
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
- **Auto-start**: Slack, Thunderbird, Firefox, Ghostty+zellij, DataGrip (assigned to specific workspaces)
- **Window rules**: Float dialogs, PiP, file pickers. Size constraints for various apps.

### DankMaterialShell (DMS)

DMS is a **comprehensive Wayland desktop shell** built on [Quickshell](https://git.outfoxxed.me/quickshell/quickshell) (Qt/QML). It replaces the entire typical Wayland desktop toolkit stack:

| DMS replaces | Traditional tool |
|--------------|-----------------|
| Top bar/panel | Waybar, Polybar |
| App launcher | Rofi, Wofi, Fuzzel |
| Lock screen | Swaylock, Hyprlock |
| Login greeter | greetd + tuigreet/gtkgreet |
| Notifications | dunst, mako |
| Clipboard manager | cliphist, clipman |
| Screenshot tool | grim + slurp |
| Screen recorder | wf-recorder |
| Idle management | swayidle, hypridle |
| Power menu | wlogout |
| System tray | (built-in) |

#### Architecture

DMS runs as a **systemd user service** and communicates with Hyprland through:

- **IPC**: `dms ipc call <target> <method>` (e.g., `dms ipc call launcher toggle`)
- **CLI**: `dms screenshot [full] [--no-file] [--no-clipboard] [-d <dir>]`
- **Hyprland keybindings** that invoke `dms` commands (SUPER+SPACE for launcher, SUPER+SHIFT+L for lock, etc.)

#### Key IPC commands

| Command | Action |
|---------|--------|
| `dms ipc call launcher toggle` | App launcher |
| `dms ipc call powermenu toggle` | Power menu |
| `dms ipc call lock lock` | Lock screen |
| `dms ipc call plugins toggle aiAssistant` | AI assistant |
| `dms ipc call screenRecorder startRecording` | Screen recording |
| `dms ipc call screenRecorder stopRecording` | Stop recording |
| `dms ipc call mpris playPause/previous/next` | Media control |

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

| Server | Language | Notes |
|--------|----------|-------|
| rust-analyzer | Rust | Via rustaceanvim, clippy on save, nightly rustfmt |
| tsgo | TypeScript/JS | Go-based native LSP (typescript-go package), formatting disabled (prettier handles it) |
| nixd | Nix | |
| emmylua_ls | Lua | Workspace includes all plugin paths |
| bashls | Bash | |
| yamlls | YAML | SchemaStore integration |
| jsonls | JSON | SchemaStore integration |
| eslint | JS/TS | Also used as linter |
| taplo | TOML | |
| harper_ls | Grammar | Checks prose in comments |
| docker LSPs | Docker | dockerfile + compose |
| qmlls | QML | For Quickshell/DMS development |
| gdscript | GDScript | Godot engine |

### Formatters (conform.nvim)

CSS/HTML/JS/TS/JSON/YAML: prettier | Lua: stylua | Nix: alejandra | Python: black | Shell: shfmt | SQL: sqlfluff | Markdown: markdownlint | Rust: rustfmt (via rust-analyzer, nightly)

### Linters (nvim-lint)

Dockerfile: hadolint | JS/TS: eslint | Lua: selene | Markdown: markdownlint + write_good + codespell | Nix: statix + deadnix | YAML: yamllint + actionlint

### Keybinding philosophy

- **Leader**: Space. **Local leader**: `\`
- **Vim-centric**: modal editing, motions enhanced (flash, treesitter textobjects)
- **Mnemonic groups**: `<leader>l` LSP, `<leader>g` Git, `<leader>h` Gitsigns, `<leader>r` Rust, `<leader>t` Trouble, `<leader>p` search/grep, `<leader>v` Vim internals, `<leader>a` AI
- **Zellij integration**: `<C-h/j/k/l>` in normal mode moves between Neovim splits and falls through to Zellij panes at edges (via vim-zellij-navigator)
- **No arrow key dependency**: `<C-h/j/k/l>` provides cursor movement in insert/command mode
- **Clipboard isolation**: system clipboard NOT synced by default; `<leader>c` in visual mode copies explicitly

### AI integration

OpenCode TUI (vim fork) runs standalone alongside neovim, connected via nvim-mcp:

- **Vim mode**: Full modal editing in the TUI prompt input (hjkl, w/b/e, dd, cw, yy, p, u, visual mode)
- **nvim-mcp**: MCP server connecting OpenCode to the running neovim instance via msgpack-RPC socket. Gives OpenCode access to open buffers, cursor position, diagnostics, selections, and in-buffer editing with full undo support.
- **Socket discovery**: Neovim creates a socket at `~/.cache/nvim/server-<ZELLIJ_SESSION_NAME>.pipe`. The nvim-mcp wrapper reads `ZELLIJ_SESSION_NAME` at runtime to connect to the correct instance.
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

| Agent | Mode | Role | Notable permissions |
|-------|------|------|---------------------|
| `build` | primary | Full development (unchanged) | `edit: allow`; `datadog_*` + ticket writes denied |
| `plan` | primary (default) | Read-only analysis/planning | `edit: deny`; gh/ticket writes + `datadog_*` denied |
| `pair` | primary | Read-only pairing companion — annotates the editor (highlights/virtual text) but never edits | `edit: deny`; mutating nvim tools (`nvim_find_and_replace_buf`, `nvim_write_full_buf`, `nvim_send_keys`) denied, `nvim_send_command: ask`; read/annotation nvim tools allowed |
| `reviewer` | subagent | Pre-commit/PR code review | `edit: deny`; read-only git bash + `gh_*_read` |
| `troubleshoot` | subagent | Incident/issue investigation via Datadog (only agent with `datadog_*` enabled). Prompt encodes skill-discovery-first + logs→traces→metrics methodology | `datadog_*: allow`; `edit: deny` |
| `tickets` | subagent | Linear/Notion triage, spec writing, status updates | reads allowed; `linear_*`/`Notion_*` writes `ask` |
| `test-writer` | subagent | Writes tests only; prompt forbids editing implementation | `edit: ask` (build-tier) |

### Commands (`modules/programs/opencode/commands/*.md` → `~/.config/opencode/command/`)

Markdown command templates using `!` `` `cmd` `` shell injection and `$ARGUMENTS`.

| Command | Agent | Purpose |
|---------|-------|---------|
| `/commit` | build | Drafts a conventional commit message from `git diff --cached`, commits after approval (never pushes) |
| `/pr` | build | Drafts a PR description from the branch diff, opens via `gh_pr_write` after approval |
| `/review` | reviewer (subtask) | Delegates the current diff/branch/PR to the `reviewer` subagent |

Both agents and commands are plain markdown, so they deploy via `xdg.configFile` **symlinks** (the Bun symlink issue only affects the `.ts` custom tools). The loader scans both `agent/`+`agents/` and `command/`+`commands/`.

### MCP servers

Always available:

| Server | Type | Purpose |
|--------|------|---------|
| Context7 | local (`@upstash/context7-mcp`) | Library documentation (64k min tokens) |
| nvim | local (nix run `nvim-mcp` wrapper) | Neovim instance access via msgpack-RPC (auto-connects to zellij session socket) |
| nixos | local (nix run `github:utensils/mcp-nixos`) | nixpkgs / NixOS / HM / darwin option + package lookup |

Linux-only (gated via `lib.optionalAttrs (!isDarwin)` — not present on the Mac mini):

| Server | Type | Purpose |
|--------|------|---------|
| Notion | remote | Notion workspace access |
| linear | local (npx mcp-remote) | Issue tracking |
| datadog | remote (EU endpoint) | Observability/monitoring |

### Custom tools (deployed to `~/.config/opencode/tools/`)

Tools are TypeScript files using `@opencode-ai/plugin` SDK, executing shell commands via `Bun.$`. Deployed via `home.activation` (cp, not symlink) due to Bun module resolution issue with Nix store symlinks (tracked: <https://github.com/anomalyco/opencode/issues/5914>).

| Tool file | Exports | Purpose |
|-----------|---------|---------|
| `date.ts` | `date` | Date arithmetic via Unix `date` command |
| `gh.ts` | 12 tools (read/write split) | GitHub CLI wrapper: issues, PRs, workflows, runs, search, status, repos |
| `google_calendar.ts` | `google_calendar` | Read-only Google Calendar via `gcalcli` |

### Bash permission philosophy

**Default-deny, explicit-allow with read/write split:**

- `"*" = "ask"` — global default, all unknown commands require approval
- Read-only commands auto-allowed: git inspection, file reading (`cat`, `ls`, `bat`), search (`rg`, `fd`, `grep`), text processing (`jq`, `yq`, `awk`), system info, network inspection (`curl`, `dig`), language toolchains (cargo, node, nix), gh CLI reads
- All mutations require approval: file writes, git commits/push, package installs, gh writes
- Custom tools: `*_read` tools are `"allow"`, `*_write` tools are `"ask"`
- **The whitelist is factored into a `readOnlyBash` `let` binding and applied per-agent.** Agent permissions override the global block, so a built-in agent (e.g. `plan`) would otherwise reset `bash` to `ask` and ignore the global allows — every agent that should run read-only bash re-applies `readOnlyBash` explicitly.
- Whitelist entries include **bare-command variants** (`"head"` alongside `"head *"`) because each segment of a pipeline (`rg foo | head`) is matched individually — a bare `head` would not match `"head *"`.

## Security Model

- **Disk encryption**: LUKS with TPM2 auto-unlock + FIDO2 backup
- **Authentication**: PAM with fingerprint (fprintd) + U2F (YubiKey) as `sufficient` alternatives
- **Secrets**: sops-nix with age (per-machine key) + GPG (YubiKey master key)
- **GPG**: YubiKey-backed key for git signing, SSH auth (gpg-agent), password store, sops decryption
- **Immutable users**: `users.mutableUsers = false`

## Theming

The entire system uses **Catppuccin Mocha**:

- GRUB, Plymouth, Hyprland, DMS, Ghostty, Neovim, Firefox, bat, delta, starship, skim, yazi, zellij
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
```

## Editing Guidelines

- **Use the `nixos` MCP** when working with anything Nix: look up package names/attributes, verify NixOS / home-manager / nix-darwin option names and types, check flake inputs, or confirm a package exists in a channel — before writing or changing config. Your training data lags nixpkgs, so prefer it over guessing option/package names. It can also **read the Nix store directly** (`action: store` with `type: ls` or `type: read` on a `/nix/store/...` path) — use it to inspect a built derivation's contents, wrappers, `nix-support/` metadata, or config files without shelling out.
- **Nix files**: Format with `alejandra`. Follow `den.aspects` pattern for new modules.
- **Lua files**: Format with `stylua`. Follow `plugins/<name>.lua` pattern for new plugin configs. Use `lze` spec format (event, cmd, keys, ft for lazy loading).
- **KDL files** (zellij): All directional bindings use hjkl, no arrow keys.
- **Hyprland config**: All directional bindings use hjkl, no arrow keys. `$mainMod` is SUPER.
- **macOS (nix-darwin)**: New Darwin config goes in a `darwin = { ... }` aspect block. yabai/skhd bindings use hjkl with `alt` as the modifier (no arrow keys). Homebrew casks are declared in `macmini.nix` (`cleanup = "zap"` removes undeclared ones).
- **OpenCode tools**: TypeScript using `@opencode-ai/plugin` SDK. Deploy via `home.activation` copy (not xdg.configFile symlink).
- **Secrets**: Never commit plaintext secrets. All secrets go through sops-nix. API keys are in `modules/security/secrets/env.yaml`.
- **Flake inputs**: Declare per-module using `flake-file.inputs`, not in `flake.nix` directly.

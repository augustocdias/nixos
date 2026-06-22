# NixOS Configuration — Dendritic Flake

A fully declarative NixOS configuration for a single-user Intel laptop running Hyprland + DankMaterialShell on Wayland. Managed with the **Den** framework for composable, aspect-based module organization.

## Framework & Module System

### Core stack

| Framework | Repo | Purpose |
|-----------|------|---------|
| **Den** | `vic/den` | Host/user/aspect composition framework |
| **flake-parts** | `hercules-ci/flake-parts` | Modular flake composition |
| **import-tree** | `vic/import-tree` | Recursive auto-discovery of all `.nix` files under `modules/` |
| **flake-file** | `vic/flake-file` | Distributed flake input declarations — each module declares its own inputs |

### How it works

1. `import-tree ./modules` discovers every `.nix` file recursively and imports it as a flake-parts module.
1. Each module registers **aspects** via `den.aspects.<name>` and optionally declares flake inputs via `flake-file.inputs.<name>`.
1. `flake.nix` is **auto-generated** — run `nix run .#write-flake` to regenerate it from module declarations.
1. Files prefixed with `_` (e.g., `_plugins.nix`, `_hardware-configuration.nix`) are skipped by import-tree and imported manually where needed.

### Aspects

Aspects are the fundamental composable unit. Each aspect can contain:

- `nixos = { ... }` — NixOS system-level config
- `homeManager = { ... }` — Home Manager user-level config
- `includes = [ ... ]` — Dependencies on other aspects

The composition chain: `den.hosts.x86_64-linux.laptop` -> `den.aspects.laptop` (hardware) -> `users.augusto` -> `den.aspects.augusto` (includes 40+ aspects).

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
  defaults.nix              # Global defaults: nix settings, GC, stateVersion 26.11
  dendritic.nix             # Bootstraps den + flake-file
  hosts.nix                 # Host definitions (laptop active, raspi planned)
  inputs.nix                # Core flake inputs (nixpkgs, den, home-manager, sops-nix)
  dev-shells.nix            # devShells.nvim-dev for plugin development
  installer.nix             # Custom NixOS installer ISO

  core/
    disko.nix               # Declarative disk partitioning
    locale.nix              # Timezone (Europe/Berlin), locales (en_US, de_DE, pt_BR)
    users.nix               # User definition (augusto, immutable, fish shell)

  hardware/
    input-devices.nix       # Fingerprint reader (fprintd), touchpad
    networking.nix          # NetworkManager, systemd-resolved, Bluetooth
    laptop/laptop.nix       # Main hardware profile: NVMe, Intel GPU, PipeWire, CUPS

  desktop/
    boot.nix                # GRUB (Catppuccin theme), Plymouth, LUKS/TPM2
    hyprland.nix            # Hyprland Wayland compositor (see Desktop section)
    login-manager.nix       # Pulls in the DMS aspect
    dms/dms.nix             # DankMaterialShell — full desktop shell (see DMS section)

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
    augusto.nix             # User aspect: includes all 40+ aspects
```

## Host Configuration

| Host | Platform | Status | Description |
|------|----------|--------|-------------|
| `laptop` | x86_64-linux | Active | Intel laptop (Arrow Lake, NPU, Thunderbolt), dual monitor (eDP-1 + DP-1) |
| `raspi` | aarch64-linux | Planned | Headless Raspberry Pi server (empty directory) |

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
- **Greeter**: DMS also serves as the display manager. Shares theme state with user session via symlinks in `/var/cache/dms-greeter/`
- **Control center**: volume, brightness, WiFi, Bluetooth, audio I/O, DND, idle inhibitor, VPN, KDE Connect
- **Notifications**: 5s timeout (normal), persistent (critical), 50 history items, 7-day retention
- **Desktop widgets**: system monitor (CPU/RAM/network/disk) + weather forecast
- **Wallpaper**: cycling every 300s from `~/media/wallpapers/`
- **Power management**: AC: 10min screen off, 3min lock, 30min suspend. Battery: power-saver profile, 20min suspend.
- **Dynamic theming**: not enabled. only active to make dank set colors for gtk and qt apps.
- **Plugins**: dankBatteryAlerts, dankKDEConnect, dankHyprlandWindows, dankDesktopWeather, displaySettings, developerUtilities, wallpaperCarousel, sessionPower, aiAssistant (Anthropic Claude)
- **AI assistant**: built-in, uses Anthropic Claude Opus 4

#### DMS Nix structure

- NixOS module (`nixosModules.greeter`): greeter service with Hyprland as compositor, PAM service `dankshell`
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

- **Model**: `anthropic/claude-opus-4-6`
- **Default agent**: `plan`
- **TUI theme**: `catppuccin-macchiato`

### MCP servers

| Server | Type | Purpose |
|--------|------|---------|
| Notion | remote | Notion workspace access |
| Linear | local (npx mcp-remote) | Issue tracking |
| Context7 | local (@upstash/context7-mcp) | Library documentation (64k min tokens) |
| Datadog | remote (EU endpoint) | Observability/monitoring |
| nvim | local (uvx nvim-mcp) | Neovim instance access via msgpack-RPC (auto-connects to zellij session socket) |

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
# Rebuild NixOS
sudo nixos-rebuild switch --flake .

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

- **Nix files**: Format with `alejandra`. Follow `den.aspects` pattern for new modules.
- **Lua files**: Format with `stylua`. Follow `plugins/<name>.lua` pattern for new plugin configs. Use `lze` spec format (event, cmd, keys, ft for lazy loading).
- **KDL files** (zellij): All directional bindings use hjkl, no arrow keys.
- **Hyprland config**: All directional bindings use hjkl, no arrow keys. `$mainMod` is SUPER.
- **OpenCode tools**: TypeScript using `@opencode-ai/plugin` SDK. Deploy via `home.activation` copy (not xdg.configFile symlink).
- **Secrets**: Never commit plaintext secrets. All secrets go through sops-nix. API keys are in `modules/security/secrets/env.yaml`.
- **Flake inputs**: Declare per-module using `flake-file.inputs`, not in `flake.nix` directly.

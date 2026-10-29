# System reference

Read before changing hosts, aspects, inputs, layout, boot, networking, power, security, deployment, or common administration. Source files remain authoritative for current values.

## Framework & Module System

### Core stack

| Framework             | Repo                         | Purpose                                                                     |
| --------------------- | ---------------------------- | --------------------------------------------------------------------------- |
| **Den**               | `vic/den`                    | Host/user/aspect composition framework                                      |
| **flake-parts**       | `hercules-ci/flake-parts`    | Modular flake composition                                                   |
| **import-tree**       | `vic/import-tree`            | Recursive auto-discovery of all `.nix` files under `modules/`               |
| **flake-file**        | `vic/flake-file`             | Distributed flake input declarations — each module declares its own inputs  |
| **flake-aspects**     | `vic/flake-aspects`          | Aspect schema support for Den                                               |
| **home-manager**      | `nix-community/home-manager` | User-level config on both NixOS and Darwin                                  |
| **nix-darwin**        | `nix-darwin/nix-darwin`      | macOS system management for the Mac mini                                    |
| **nix-homebrew**      | `zhaofengli/nix-homebrew`    | Declarative Homebrew (casks) on Darwin                                      |
| **nixos-raspberrypi** | `nvmd/nixos-raspberrypi`     | Raspberry Pi 4 boot: firmware partition, config.txt, vendor kernel+firmware |
| **sops-nix**          | `Mic92/sops-nix`             | Secrets management                                                          |
| **jail-nix**          | `~alexdavid/jail.nix`        | Bubblewrap combinator library (sourcehut) — backs the agent sandbox         |

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

Composition chains:

- **laptop**: `den.hosts.x86_64-linux.laptop` -> `den.aspects.laptop` (hardware) -> `users.augusto` -> `den.aspects.user-linux`
- **macmini**: `den.hosts.aarch64-darwin.macmini` -> `den.aspects.macmini` (hardware) -> `users.augusto` -> `den.aspects.user-macos`
- **raspi**: `den.hosts.aarch64-linux.raspi` -> `den.aspects.raspi` (hardware + services), with no Home Manager user

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
  hosts.nix                 # Host definitions (laptop / macmini / raspi)
  inputs.nix                # Core flake inputs (nixpkgs, den, home-manager, sops-nix, darwin, nix-homebrew)
  dev-shells.nix            # devShells.default (nix tooling) + devShells.nvim-dev; formatter = alejandra
  installer.nix             # Custom NixOS installer ISO

  core/
    disko.nix               # Declarative disk partitioning
    locale.nix              # Timezone (Europe/Berlin), locales (en_US, de_DE, pt_BR)
    users.nix               # User definition (augusto, immutable, fish shell)

  hardware/
    input-devices.nix       # Fingerprint reader (fprintd), touchpad
    networking.nix          # NetworkManager, systemd-resolved, Bluetooth
    laptop/laptop.nix       # NixOS hardware profile: NVMe, Intel GPU, PipeWire, CUPS, aarch64 binfmt
    macmini/macmini.nix     # Darwin host: nix-homebrew, Touch ID sudo, system.defaults, EurKEY-Next layout, 1Password, casks
    raspi/raspi.nix         # Raspberry Pi 4: disko/GPT, direct kernel boot, vendor kernel, networkd, BLE, nixos-level sops

  desktop/
    boot.nix                # GRUB, Plymouth, LUKS/TPM2
    hyprland.nix            # Hyprland Wayland compositor (see docs/desktop.md)
    login-manager.nix       # Pulls in the DMS aspect
    dms.nix                 # DankMaterialShell — full desktop shell (see docs/desktop.md)
    omniwm.nix              # macOS tiling WM, built-in hotkeys, alt-based hjkl bindings

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
    herdr/                  # Herdr agent multiplexer (see docs/herdr.md)
    mpv.nix                 # MPV with hardware decoding
    neovide.nix             # Neovide (Neovim GUI) via home-manager's programs.neovide
    neovim/                 # Neovim — extensive config (see docs/neovim.md)
    agent-jail/             # shared bubblewrap jail (mkJail), host-query, host_* MCP shim
    agent-shared/           # prompts/context/skills + bash ruleset shared by omp + claude-code
    claude-code/            # Claude Code — work harness (see docs/coding-agents.md)
    omp/                    # oh-my-pi — personal harness (see docs/coding-agents.md)
    skim.nix                # Skim fuzzy finder with rg/fd/bat
    starship.nix            # Starship prompt with Catppuccin powerline segments
    stylua.nix              # StyLua config
    thunderbird/            # Thunderbird with extensions
    xdg.nix                 # XDG dirs and MIME associations
    zapfast.nix             # ZapFast native WhatsApp client
    yamllint/               # Yamllint config
    yazi/                   # Yazi file manager with plugins

  services/
    podman.nix              # Podman with Docker compatibility
    mosquitto.nix           # `mosquitto` aspect (raspi only): MQTT broker, auth required
    home-assistant/
      home-assistant.nix    # `home-assistant` aspect (raspi only): HA + matterjs-server
      _components.nix       # enumerated extraComponents — also drives systemd hardening
      _lovelace-modules.nix # 6 cards nixpkgs lacks (ex-HACS)
      _themes.nix           # 3 themes nixpkgs lacks (ex-HACS)
      _berlin-transport.nix # berlin_transport custom component (ex-HACS)
      _snapmaker-u1.nix     # snapmaker_u1 custom component (Moonraker on the U1 printer; tracks master)
      _ha-mcp.nix           # ha_mcp_tools custom component (server = nixpkgs' python3Packages.ha-mcp)
      pins.nix              # the 13 hand-pinned sources as packages.hass-*, for nix-update
      _laya.nix             # our own `laya` conversation agent, built from ./laya (no upstream, not pinned)
      laya/                 # its source; pipeline.py is pure stdlib and shared with laya-eval
      laya-eval/            # offline accuracy harness: eval.py + cases.json (home snapshot lives in /tmp, never in the repo)
    laya/
      laya.nix              # `laya` aspect (macmini only): laya.serve, LAN-bound, no auth
    libretranslate/
      libretranslate.nix    # `libretranslate` aspect (macmini only): en<->pt translation for laya, port 5001
    ollama/
      ollama.nix            # macmini-only server/loader, official binary and source-update outputs
    wyoming.nix            # macmini-only STT/TTS daemons, pinned voices, state activation
    honcho/
      honcho.nix            # macmini-only PostgreSQL/bootstrap/API/deriver boot services
    hermes-agent/
      hermes-agent.nix      # macmini-only upstream Nix package, one multiplexed boot gateway
    open-webui/
      open-webui.nix        # macmini-only authenticated LAN listener, account/model bootstrap
    work/
      work.nix              # `work` aspect: aggregates the below + claude-code(+jail), just, awscli2
      jgrep.nix             # jgrep semantic code search (TypeSafe Jev); skill → Claude only
      datagrip.nix          # JetBrains DataGrip with plugins
      virtualization.nix    # libvirtd/QEMU
      wireguard.nix         # WireGuard tools
      slack.nix             # Slack desktop
      lotion.nix            # Custom Notion desktop client (Electron, AST-patched for SSO)
      teamviewer.nix        # TeamViewer

  security/
    security.nix            # PAM (fingerprint + U2F), TPM2, GPG agent (default pinentry), polkit
    secrets/                # SOPS-nix secrets (API keys, tokens, encrypted env.yaml)

  scripts/
    update-system/          # System update script

  user/
    base.nix                # `user-base` aspect: cross-platform aspects (build on both nixos + darwin)
    linux.nix               # `user-linux` aspect: user-base + Hyprland, DMS login, Firefox, Thunderbird, work, etc.
    mac.nix                 # `user-macos` aspect: user-base + Darwin-only packages (1Password CLI, godot, raycast)
```

## Host Configuration

| Host      | Platform       | hostName  | Status | Description                                                                                                                 |
| --------- | -------------- | --------- | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| `laptop`  | x86_64-linux   | `nixos`   | Active | Intel laptop (Arrow Lake, NPU, Thunderbolt), dual monitor (eDP-1 + DP-1). NixOS + Hyprland + DMS.                           |
| `macmini` | aarch64-darwin | `macmini` | Active | Apple Silicon Mac mini. macOS via nix-darwin + nix-homebrew, OmniWM tiling, EurKEY-Next layout. Also hosts the voice stack. |
| `raspi`   | aarch64-linux  | `home`    | Active | Raspberry Pi 4B 8GB, headless Home Assistant. No home-manager user; boots from microSD, no u-boot.                          |

### macOS (nix-darwin) host — `macmini`

Managed entirely through `modules/hardware/macmini/macmini.nix` (aspect `den.aspects.macmini`, class `darwin`):

- **nix-homebrew**: declarative Homebrew, Rosetta disabled, `cleanup = "zap"` (removes anything not declared). Casks: autodesk-fusion, vlc, blender, orcaslicer, snapmaker-orca, mac-mouse-fix, freecad.
- **Auth**: Touch ID for `sudo` (`security.pam.services.sudo_local.touchIdAuth`).
- **system.defaults**: dark mode, show-all-extensions/files, fast key repeat, disabled autocorrect/substitutions, dock autohide, Finder list view + path/status bar, screenshots to `~/pictures/screenshots`, trackpad tap-to-click + three-finger drag, Spotlight hotkeys disabled.
- **Keyboard**: CapsLock -> Control; **EurKEY-Next** layout bundle built from the `eurkey-next` flake input and installed to `/Library/Keyboard Layouts/` via a post-activation script.
- **Window management**: `omniwm` aspect (see [Desktop](desktop.md#window-management--omniwm)).
- **Remote access**: `services.openssh.enable = true` — bootstraps `com.openssh.sshd` via `launchctl`, avoiding `systemsetup -setremotelogin` and its Full Disk Access requirement. `users.users.augusto.openssh.authorizedKeys.keys` holds the YubiKey-backed ed25519 key (the same one `raspi.nix` accepts); nix-darwin renders it to `/etc/ssh/nix_authorized_keys.d/augusto` and points sshd's `AuthorizedKeysCommand` at it rather than writing `~/.ssh/authorized_keys`.
- **Power**: `sleep.computer = "never"` + `restartAfterPowerFailure` — the voice stack depends on this host staying up.
- **Voice stack**: macmini includes the `ollama` and `wyoming` Darwin service aspects. `modules/services/ollama/ollama.nix` owns the server and model loader; `modules/services/wyoming.nix` owns two independent speech daemons, pinned Portuguese voice metadata, and voice/state activation. Endpoints remain `OLLAMA_HOST=[::]:11434`, Whisper port 10300 (`--language auto`, `HF_HOME=/tmp`), and Piper port 10200.
  - **launchd system daemons inherit only `PATH`** — no `HOME`. Ollama receives `HOME=/var/lib/ollama`. Each service declares its own `/var/log/<name>.log` stdout/stderr paths. Service aspects own their state-directory activation; the host retains keyboard activation.
  - **Historical Qwen deployment checks**: `OLLAMA_CONTEXT_LENGTH=65536`, `OLLAMA_KEEP_ALIVE=-1`, `OLLAMA_FLASH_ATTENTION=1`, and `OLLAMA_NUM_PARALLEL=3`. Both launchd configuration and the running process environment were checked after the rebuild; the user's parallelism value of 3 was preserved. `qwen3.5:9b-mlx` and `qwen3-embedding:0.6b` were deployed at that time. The M4/32 GiB host ran the actual MLX runner, with 99% GPU utilization observed. Earlier swap usage was about 5.4 GiB, but its causal contribution was not established. Isolated tiny prompts at context limits 65536 and 262144 started thinking in under 0.4 seconds and decoded about 16 tokens/second. After the rebuild, a synthetic 19,046-token request to the production server took 88.247 seconds to its first word: 88.086 seconds of prompt processing, 0.005 seconds of model loading/scheduling, and 0.120 seconds of generation. This establishes a substantial full-prompt processing cost, not the exact cause of every historical 5–10-minute chat. The lower context is a headroom cap, not a demonstrated standalone speed fix; occupied-context capacity, simultaneous inference, and end-to-end Hermes latency remain separate checks.
  - **MLX scheduling limitation**: the exact [Ollama v0.40.11 runner](https://github.com/ollama/ollama/blob/v0.40.11/mlxrunner/runner.go) synchronously executes each request's complete pipeline before accepting another request. `OLLAMA_NUM_PARALLEL=3` does not create three text-generation slots on this MLX path. Long background Honcho calls can therefore queue foreground chat; increasing the setting or shrinking only the context cap does not fix that scheduling limitation. Do not apply llama.cpp concurrency assumptions to this runner. Comparing an alternative model/backend requires a controlled shared-service interruption, not silently replacing the active model.
  - **Shared generation model**: `services.ollama.model` defaults to `gpt-oss:20b` in `modules/services/ollama/ollama.nix`. Change that default once to update the Ollama loader, Hermes host and both personal profiles, and all nine Honcho generation roles. Embeddings remain `qwen3-embedding:0.6b`. Rebuild and restart the affected services, then start a fresh Hermes conversation to use the new model. The historical MLX measurements above do not establish GPT-OSS performance.
  - **Models are declared in Nix but not hash-pinned.** The `ollamaModels` list drives an `ollama-model-loader` daemon (`KeepAlive.SuccessfulExit = false`, i.e. retry-on-failure only) that polls `127.0.0.1:11434/api/version` — launchd has no ordering — then `ollama pull`s each entry. Re-pulling an existing model is a no-op, so running it every boot is free. True pinning would mean `fetchurl` a GGUF plus `ollama create`, which still needs a live server, doubles disk, and loses the model's curated chat/tool-call template — not worth it.
  - **Official release packaging**: `modules/services/ollama/_package.nix` pins Ollama 0.40.11. The complete upstream Darwin archive stays together under `libexec/ollama`; both server and loader use its `bin/ollama` symlink. No fixup, stripping, or re-signing runs. `packages.<system>.ollama-darwin-source` uses a native fetcher on Linux and Darwin; only Darwin exports `ollama-bin`.
  - **Pinned updates**: `update-system` stage 2 updates Home Assistant and Ollama; `--skip-pins` skips both. Ollama uses `nix-update --src-only --version=stable --use-github-releases` and the helper's explicit filename. HA retains `--build`; Darwin additionally builds `ollama-bin`, while Linux reports runtime verification outstanding. Per-pin failures appear in the final summary. Updates do not activate services or change model tags.
  - Metal works fine from a root daemon (`library=Metal name=MTL0 description="Apple M4"`). A one-off `llama-server GPU discovery watchdog timed out` on a cold start is not a real CPU fallback.
- **Open WebUI and Hermes**: WebUI remains LAN-bound on port 8080, with declared password authentication and per-person loopback Hermes connections. Hermes runs as `augusto` at boot, alongside native Honcho/PostgreSQL. See [Open WebUI](voice-services.md#open-webui), [Hermes Agent](voice-services.md#hermes-agent), and [Honcho](voice-services.md#honcho) for credential, state, and verification boundaries.
- **Laya**: decision-model server for the HA `laya` agent, `0.0.0.0:8000`, plus **LibreTranslate** on `0.0.0.0:5001` in front of it. Port 5001 avoids AirPlay's port 5000 without changing AirPlay. Existing HA entries need URL reconfiguration after deployment. See [Laya](voice-services.md#laya).
- **Other**: 1Password GUI, fish as login shell.

### Raspberry Pi host — `raspi`

Headless Home Assistant appliance. Defined by `modules/hardware/raspi/raspi.nix` (aspect `den.aspects.raspi`) plus `den.aspects.home-assistant`. `hostName = "home"`, so it is reachable as `home.local`.

- **No home-manager user.** `den.hosts.aarch64-linux.raspi` declares no `users`, because the `user-*` aspects drag in nightly-overlay Neovim and 50+ plugins. `augusto` is a plain OS user (wheel, fish, SSH key only, passwordless sudo so `--target-host` runs unattended).
- **Deliberately does not include the `networking`, `boot`, `locale` or `users` aspects** — all are laptop-shaped (BT audio profiles + `extraHosts`; GRUB/Plymouth/LUKS; hunspell + xkb; a `hashedPasswordFile` under `/etc/nixos/secrets`). Timezone/locale/console are set inline instead.
- **Boot is `nixos-raspberrypi` with `boot.loader.raspberry-pi.bootloader = "kernel"`** — the GPU firmware loads the kernel directly. There is no u-boot and no `extlinux.conf`; `boot.loader.generic-extlinux-compatible` is off. The `"kernel"` bootloader (as opposed to the older `"kernelboot"`) keeps multiple generations, capped at `configurationLimit = 4`. `raspberry-pi-4.base` imports set `enable`, `arm_64bit`, `enable_uart`, `avoid_warnings` and `hardware.enableRedistributableFirmware` — don't re-declare them. Layout is disko GPT: 512M vfat `FIRMWARE` at `/boot/firmware`, ext4 `NIXOS` at `/`.
- **Vendor kernel from nixos-raspberrypi's cachix.** `raspberry-pi-4.base` selects `linuxPackages_rpi4` from that flake's own `packages`, built against *its* pinned nixpkgs, so `nixos-raspberrypi.cachix.org` (declared in `modules/defaults.nix`, needed on the **laptop** because it builds the closure) serves it prebuilt. That kernel predates the `target`/`buildDTBs` passthru attrs 26.11 reads, so `vendorLinuxPackages` in `raspi.nix` adds them via `overrideAttrs`; `passthru` is stripped before derivation creation, so `drvPath` is unchanged and the cache still hits. `hardware.deviceTree.enable` is set explicitly because its default reads the missing `buildDTBs`, and the generation's `dtbs` symlink is what the bootloader's installer copies to the firmware partition.
- **Bluetooth works via the vendor kernel plus `raspberry-pi-4.bluetooth`**, which sets `krnbt=on` so `hci0` binds without `btattach`. The generic `pkgs.linuxPackages` does *not* get BLE up on this board.
- **`gpio`/`pwm0` are not provided by nixos-raspberrypi.** The gpio group, `iomem=relaxed` and the udev rules are inlined in `raspi.nix`. `pwm0` is not configured; it needs a `dtoverlay` through `hardware.raspberry-pi.config`, not `hardware.deviceTree.overlays`.
- **`installDisk` in `raspi.nix` is a placeholder** and must be set to the real `/dev/disk/by-id/mmc-*` before running disko. It only affects the format step: runtime `fileSystems` resolve via `/dev/disk/by-partlabel/disk-main-*`.
- **Networking**: systemd-networkd + DHCP on `en*`/`eth*` with `ClientIdentifier = "mac"`, resolved, and avahi publishing addresses for `home.local`. The router holds a static reservation keyed on the MAC — the HomeKit bridge (port 21064) is IP-sensitive. Firewall opens 8123, 21064, 1883 and 5353/udp. The board has no RTC, so the clock is wrong until timesyncd syncs a few seconds into boot.
- **sops at NixOS level** (`sops.age.keyFile = /var/lib/sops-nix/key.txt`) — the first place in this repo to use it; the `secrets` aspect is home-manager only. The host's age key is a recipient of `env.yaml`, so it never needs the YubiKey; the YubiKey is only needed to re-key, on the laptop. `sops-install-secrets` validates every declared secret against `env.yaml` at **build** time, so a missing key fails on the laptop rather than during activation on the Pi.
- **MQTT broker** (`mosquitto` aspect): mosquitto on 1883, reachable on the LAN. There is no anonymous access — `omitPasswordAuth` defaults false, so the password-file plugin is always loaded. One user per consumer, each with its own sops-backed password (`mqtt_<name>_password` in `env.yaml`) and its own ACL; adding a consumer is one line in the `consumers` attrset plus the matching secret. `passwordFile` takes the *plaintext* and is hashed at activation by `mosquitto_passwd -U`; both it and the ACL are handed over via systemd `LoadCredential`, read as root before privileges drop, so a default root-owned `0400` secret needs no `owner`/`mode`. Changing the consumer set **restarts** the broker (`preStart` regenerates passwd/acl and the module sets no `reloadTriggers`); `persistence` keeps subscriptions and retained messages. No TLS — plaintext on the LAN, not port-forwarded.
- **Deployment**: built on the laptop (`boot.binfmt.emulatedSystems = ["aarch64-linux"]`) and pushed with `nixos-rebuild --flake .#raspi --target-host`. The Pi needs no build scratch space and no repo checkout.
- **journald** is capped at 200M; the default is 10% of the filesystem, i.e. ~12G of needless flash wear.

## Security Model

- **Disk encryption**: LUKS with TPM2 auto-unlock + FIDO2 backup
- **Authentication**: PAM with fingerprint (fprintd) + U2F (YubiKey) as `sufficient` alternatives
- **Secrets**: sops-nix with age (per-machine key) + GPG (YubiKey master key)
- **GPG**: YubiKey-backed key for git signing, SSH auth (gpg-agent), password store, sops decryption
- **Immutable users**: `users.mutableUsers = false`
- **Agent sandbox (Linux)**: `claude` and `omp` run inside the shared bubblewrap jail — deny-by-default writes, no setuid, no gpg signing socket. Herdr is reachable only through a per-pane relay that forwards status/sidebar/session reports and denies everything else (nvim's socket is not bound at all). See [Agent sandbox](coding-agents.md#agent-sandbox-linux-only).

## Theming

The entire system uses **Catppuccin Mocha**:

- Hyprland, DMS, Ghostty, Neovim, Firefox, bat, delta, starship, skim, yazi, herdr
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

# Deploy the Pi (built here via aarch64 binfmt, closure pushed over SSH)
nixos-rebuild switch --flake .#raspi --target-host augusto@home.local --sudo

# Partition + install the Pi's card (card in the laptop's reader; set
# `installDisk` in raspi.nix first)
sudo nix run github:nix-community/disko -- --mode destroy,format,mount \
  --flake .#raspi
sudo nixos-install --root /mnt --flake .#raspi --no-root-password

# Regenerate flake.nix after changing module inputs
nix run .#write-flake

# Update all neovim plugins
nix flake update nvim-*
# or use the wrapper script:
update-nvim

# Update system packages (flake inputs, HA pins, Firefox, Thunderbird)
update-system
update-system --skip-pins        # skip the HA pins; each one is built

# Bump a single hand-pinned Home Assistant source (needs the dev shell)
nix-update -f ~/nixos -F --build --version=stable hass-status-card

# Update Firefox/Thunderbird extensions
update-firefox
update-thunderbird

# Dev shell for working on this config (nix lang tooling, sops, linters).
# `.envrc` is `use flake`, so direnv enters it automatically on cd.
nix develop
nix fmt                          # alejandra, via perSystem.formatter

# Dev shell for neovim plugin development
nix develop .#nvim-dev

# Update herdr plugin sources (herdr itself follows nixpkgs)
nix flake update herdr-plugin-browser

# Bump omp: edit the tag in modules/programs/omp/omp.nix, then
nix run .#write-flake && nix flake update oh-my-pi

# Open (or create) a herdr workspace with the default layout
herdr-workspace                                    # current directory
herdr-workspace ~/dev/integrations-mono/main       # label defaults to integrations-mono/main
herdr-workspace ~/dev/some-repo my-name            # explicit workspace name
```

## Editing guidelines

- Use current `nixos` MCP results before changing package attributes, NixOS/Home Manager/nix-darwin options, or flake-input assumptions. Its store interface reads built outputs without shell inspection: `{"action":"store","type":"ls","query":"/nix/store/..."}` lists a directory; `{"action":"store","type":"read","query":"/nix/store/..."}` reads wrappers, generated configuration, and `nix-support/` metadata.

- **macOS (nix-darwin)**: New Darwin config goes in a `darwin = { ... }` aspect block. Homebrew casks are declared in `macmini.nix` (`cleanup = "zap"` removes undeclared ones). See [Desktop](desktop.md#window-management--omniwm) for OmniWM bindings.

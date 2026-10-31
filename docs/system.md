# System reference

[AGENTS.md](../AGENTS.md) owns the module conventions and the host table.

## Composition

Each host in `modules/hosts.nix` names a host aspect, plus a user aspect for `augusto` on laptop (`user-linux`) and macmini (`user-macos`). Both user aspects include `user-base`. raspi has a host aspect only.

All Neovim plugin inputs carry the `nvim-` prefix, so `nix flake update nvim-*` updates them alone. Keep the prefix on new plugin inputs.

To inspect built outputs, use the `nixos` MCP store interface: `{"action":"store","type":"ls","query":"/nix/store/..."}` lists a directory and `{"action":"store","type":"read","query":"/nix/store/..."}` reads a file, such as a wrapper, generated config, or `nix-support/` metadata.

<a id="macos-nix-darwin-host--macmini"></a>

## macOS (nix-darwin) host: `macmini`

`modules/hardware/macmini/macmini.nix` defines the host and includes the voice service aspects. Put Darwin config in a `darwin = { ... }` aspect block.

- **Homebrew** runs with `cleanup = "zap"`, so activation uninstalls any cask not declared in `macmini.nix`. Declare every cask there.
- **EurKEY-Next** is built from the `eurkey-next` input and copied into `/Library/Keyboard Layouts/` by a post-activation script.
- **SSH**: `services.openssh.enable` starts sshd through `launchctl`, which avoids the Full Disk Access that `systemsetup -setremotelogin` needs. nix-darwin renders the authorized key to `/etc/ssh/nix_authorized_keys.d/augusto` and points sshd's `AuthorizedKeysCommand` at it. `~/.ssh/authorized_keys` is unmanaged.
- **Power**: the host never sleeps and restarts after power failure, because the voice stack depends on it.
- **Window management**: see [Desktop](desktop.md#window-management--omniwm).

### launchd services

launchd system daemons inherit only `PATH`, with no `HOME`. Each daemon that needs a home sets one (Ollama uses `/var/lib/ollama`). Each daemon logs stdout and stderr to `/var/log/<name>.log`. Each service aspect owns its own state-directory activation.

### Ollama

`modules/services/ollama/ollama.nix` owns the server and the model loader.

- **Shared generation model**: `services.ollama.model` is the single source for the loader, Hermes (host and personal profiles), and every Honcho generation role. After changing it, rebuild, restart the affected services, and start a fresh Hermes conversation.
- **Model loader**: models are declared in Nix but not hash-pinned. `ollama-model-loader` polls `127.0.0.1:11434/api/version`, because launchd has no ordering, then pulls each model. It retries only on failure, and re-pulling an existing model is a no-op. Keep it this way. True pinning would need a live server for `ollama create`, double the disk use, and lose the model's chat and tool-call template.
- **Package**: `_package.nix` installs the official Darwin release archive intact under `libexec/ollama`. Leave it without fixup, stripping, or re-signing. `packages.<system>.ollama-darwin-source` builds on Linux and Darwin; `ollama-bin` exists only on Darwin.
- **MLX scheduling**: the Ollama MLX runner runs each request's full pipeline before accepting the next one (see the [runner source](https://github.com/ollama/ollama/blob/v0.40.11/mlxrunner/runner.go)). `OLLAMA_NUM_PARALLEL` adds no generation slots on this path, so long background Honcho calls queue foreground chat. Raising parallelism or lowering the context cap does not change that. Apply llama.cpp concurrency assumptions only to llama.cpp runners. Compare another model or backend only during a planned interruption of the shared service.
- **Metal**: a root daemon uses Metal (`library=Metal name=MTL0 description="Apple M4"`). A one-off `llama-server GPU discovery watchdog timed out` on a cold start is harmless and does not mean a CPU fallback.

### Other macmini services

Open WebUI, Hermes, Honcho, and Laya are described in [Open WebUI](voice-services.md#open-webui), [Hermes Agent](voice-services.md#hermes-agent), [Honcho](voice-services.md#honcho), and [Laya](voice-services.md#laya). LibreTranslate listens on port 5001 because AirPlay holds port 5000.

<a id="raspberry-pi-host--raspi"></a>

## Raspberry Pi host: `raspi`

Headless Home Assistant appliance, reachable as `home.local`. Defined by `modules/hardware/raspi/raspi.nix`, which includes the `home-assistant` and `mosquitto` aspects.

- **No Home Manager user**, because the `user-*` aspects pull in nightly Neovim and its plugins. `augusto` is a plain OS user with passwordless sudo, so `--target-host` deploys run unattended.
- **Host-local basics**: timezone, locale, console, users, and networking are set inline in `raspi.nix`. The shared `networking`, `boot`, `locale`, and `users` aspects are laptop-shaped (Bluetooth audio profiles, GRUB/Plymouth/LUKS, hunspell, a `hashedPasswordFile`), so raspi leaves them out.
- **Boot**: nixos-raspberrypi with `boot.loader.raspberry-pi.bootloader = "kernel"`. The GPU firmware loads the kernel directly, without u-boot or `extlinux.conf`. `raspberry-pi-4.base` already sets `enable`, `arm_64bit`, `enable_uart`, `avoid_warnings`, and `hardware.enableRedistributableFirmware`.
- **Vendor kernel**: `linuxPackages_rpi4` comes from the nixos-raspberrypi flake, built against its own nixpkgs, so `nixos-raspberrypi.cachix.org` serves it prebuilt. The laptop needs that cache in `modules/defaults.nix` because it builds the closure. The kernel lacks the `target` and `buildDTBs` passthru attributes that current nixpkgs reads, so `vendorLinuxPackages` adds them with `overrideAttrs`. Passthru does not change `drvPath`, so the cache still hits. `hardware.deviceTree.enable` is set explicitly because its default reads `buildDTBs`, and the bootloader installer copies the generation's `dtbs` to the firmware partition.
- **Bluetooth** needs the vendor kernel plus `raspberry-pi-4.bluetooth`, which sets `krnbt=on` so `hci0` binds without `btattach`. Generic `pkgs.linuxPackages` does not bring BLE up on this board.
- **GPIO and PWM**: the `gpio` group, `iomem=relaxed`, and udev rules are inlined in `raspi.nix`. To enable `pwm0`, add a `dtoverlay` through `hardware.raspberry-pi.config`, not through `hardware.deviceTree.overlays`.
- **Install disk**: `installDisk` in `raspi.nix` only affects the disko format step. Confirm it names the card reader with `lsblk -o NAME,SIZE,TRAN,FSTYPE` before running disko. Runtime `fileSystems` resolve through `/dev/disk/by-partlabel/disk-main-*`.
- **Networking**: systemd-networkd with DHCP, resolved, and avahi publishing `home.local`. The router holds a static DHCP reservation, because the HomeKit bridge (port 21064) is IP-sensitive. The board has no RTC, so the clock is wrong until timesyncd syncs a few seconds into boot.
- **Secrets**: the `secrets` aspect is Home Manager only, so `raspi.nix` imports sops-nix at NixOS level with `sops.age.keyFile = /var/lib/sops-nix/key.txt`. The host's age key is a recipient of `env.yaml`, so the Pi never needs the YubiKey. Re-keying needs the YubiKey on the laptop. `sops-install-secrets` validates declared secrets against `env.yaml` at build time, so a missing key fails on the laptop, not during activation on the Pi.
- **journald** is capped in `raspi.nix` to limit flash wear.

### MQTT broker

The `mosquitto` aspect (`modules/services/mosquitto.nix`) runs mosquitto on port 1883, reachable on the LAN without TLS and not port-forwarded. Every client authenticates.

- **Add a consumer** with one entry in the `consumers` attrset and a matching `mqtt_<name>_password` secret in `env.yaml`. Each consumer gets its own password and ACL.
- `passwordFile` takes the plaintext; `mosquitto_passwd -U` hashes it at activation. The password file and ACL reach the service through systemd `LoadCredential`, read as root before privileges drop, so a default root-owned `0400` secret needs no `owner` or `mode`.
- Changing the consumer set restarts the broker, because `preStart` regenerates the password and ACL files. `persistence` keeps subscriptions and retained messages across restarts.

## Security

- **Disk**: the laptop root is LUKS (`modules/hardware/laptop/laptop.nix`) with TPM2 auto-unlock.
- **PAM**: fingerprint and U2F (YubiKey) are `sufficient` alternatives for sudo, polkit, and login. U2F config applies only when `modules/security/_u2f_keys` exists.
- **Secrets**: sops-nix with a per-machine age key plus the YubiKey GPG master key. The YubiKey GPG key also handles git signing, SSH auth through gpg-agent, and the password store.
- **Users**: `users.mutableUsers = false`. The laptop password comes from `/etc/nixos/secrets/augusto-password`.
- **Agent sandbox (Linux)**: `claude` and `omp` run inside the shared bubblewrap jail. See [Agent sandbox](coding-agents.md#agent-sandbox-linux-only).

## Common operations

```bash
# Rebuild the laptop
sudo nixos-rebuild switch --flake .

# Rebuild the macmini
darwin-rebuild switch --flake .

# Deploy the Pi: built on the laptop through aarch64 binfmt, closure pushed over SSH
nixos-rebuild switch --flake .#raspi --target-host augusto@home.local --sudo

# Partition and install the Pi's card from the laptop's reader (confirm installDisk first)
sudo nix run github:nix-community/disko -- --mode destroy,format,mount --flake .#raspi
sudo nixos-install --root /mnt --flake .#raspi --no-root-password
sudo umount -R /mnt

# Regenerate flake.nix after changing module inputs
nix run .#write-flake

# Update Neovim plugins
update-nvim                      # or: nix flake update nvim-*

# Update flake inputs, HA and Ollama pins, Firefox and Thunderbird extensions
update-system
update-system --skip-pins        # skip the HA and Ollama pins

# Bump one hand-pinned Home Assistant source (needs the dev shell)
nix-update -f ~/nixos -F --build --version=stable hass-status-card

# Update Firefox or Thunderbird extensions alone
update-firefox
update-thunderbird

# Dev shell (nix tooling, sops, linters); direnv enters it through `.envrc`
nix develop
nix fmt                          # alejandra

# Dev shell for Neovim plugin development
nix develop .#nvim-dev

# Update herdr plugin sources (herdr itself follows nixpkgs)
nix flake update herdr-plugin-browser

# Bump omp: edit the tag in modules/programs/omp/omp.nix, then
nix run .#write-flake && nix flake update oh-my-pi
```

`update-system` pin handling needs `nix-update` from the dev shell and reports per-pin failures in its final summary. HA pins are built after updating. The Ollama pin updates only its source; on Darwin it also builds `ollama-bin`, and on Linux Darwin build and runtime verification remain outstanding. Pin updates neither activate services nor change model tags.

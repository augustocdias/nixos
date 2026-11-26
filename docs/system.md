# System reference

[AGENTS.md](../AGENTS.md) owns the module conventions and the host table.

## Composition

Each host in `modules/hosts.nix` names a host aspect, plus a user aspect for `augusto` on laptop (`user-linux`), macmini (`user-macos`) and vps-hermes (`user-server`). `user-linux` and `user-macos` include `user-base`; `user-server` takes only the shell, editor, Git, gpg and fonts. vps-hermes adds a second user, `hermes` (`user-hermes`). raspi has a host aspect only.

`modules/defaults.nix` explicitly lets hosts receive their users' OS content through `den.batteries.user-aspects`. This preserves system settings carried by the user aspects without relying on Den's transition default. Keep `user-shell` in `den.schema.user.includes`, not `den.default.includes`: the default runs in both host and user scopes and duplicates the shell provider.

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

- **Generation models**: `modules/services/hermes-agent/_models.nix` selects primary Hermes models by host and profile, including the root and Livia profiles that Open WebUI uses. `_fallbacks.nix` selects their fallback chains. The loader pulls every distinct macmini primary or fallback model configured for loopback Ollama. After changing models, rebuild, restart the affected services, and start a fresh Hermes conversation.
- **Cloud models**: `:cloud` tags run on ollama.com through the local server, so consumers keep using loopback. The daemon signs requests with `/var/lib/ollama/.ollama/id_ed25519` (its `HOME`), not your user key. Register that key once with `sudo HOME=/var/lib/ollama ollama signin`, or paste its `.pub` at ollama.com → Settings → Keys. Until then, cloud pulls fail and the loader keeps retrying. Setting `OLLAMA_NO_CLOUD` would refuse every cloud request.
- **Model loader**: models are declared in Nix but not hash-pinned. `ollama-model-loader` polls `127.0.0.1:11434/api/version`, because launchd has no ordering, then pulls each model. It retries only on failure, and re-pulling an existing model is a no-op. Keep it this way. True pinning would need a live server for `ollama create`, double the disk use, and lose the model's chat and tool-call template.
- **Package**: `_package.nix` installs the official Darwin release archive intact under `libexec/ollama`. Leave it without fixup, stripping, or re-signing. `packages.<system>.ollama-darwin-source` builds on Linux and Darwin; `ollama-bin` exists only on Darwin.
- **MLX scheduling**: the Ollama MLX runner runs each request's full pipeline before accepting the next one (see the [runner source](https://github.com/ollama/ollama/blob/v0.40.11/mlxrunner/runner.go)). `OLLAMA_NUM_PARALLEL` adds no generation slots on this path, so long background calls queue foreground chat. Raising parallelism or lowering the context cap does not change that. Apply llama.cpp concurrency assumptions only to llama.cpp runners. Compare another model or backend only during a planned interruption of the shared service. Cloud models skip the local runner.
- **Metal**: a root daemon uses Metal (`library=Metal name=MTL0 description="Apple M4"`). A one-off `llama-server GPU discovery watchdog timed out` on a cold start is harmless and does not mean a CPU fallback.

### Other macmini services

Open WebUI, Hermes, and Laya are described in [Open WebUI](voice-services.md#open-webui), [Hermes Agent](voice-services.md#hermes-agent), and [Laya](voice-services.md#laya). LibreTranslate listens on port 5001 because AirPlay holds port 5000.

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

<a id="vps-host--vps-hermes"></a>

## VPS host: `vps-hermes`

Hetzner Cloud x86_64 VPS running its own Hermes (see [Work Hermes](coding-agents.md#work-hermes)). `modules/hardware/vps-hermes/vps-hermes.nix` holds the disk, boot and network; `server-base` (`modules/core/server-base.nix`) holds the hardening any server reuses.

- **Users**: `augusto` administers the machine with passwordless sudo, for unattended deploys. Hermes runs unsandboxed, so it runs as `hermes` (uid 1001, lingering), which `vps-hermes.nix` keeps out of `wheel` (den's `primary-user` battery adds it to every user) and out of Nix's trusted users. A compromised worker reaches `hermes`'s files, its two secrets and the agent Git key, but not root or `augusto`. Manage it from `augusto` with `sudo -iu hermes`, `systemctl --user -M hermes@ restart hermes-gateway` and `journalctl --user -M hermes@ -u hermes-gateway`, or log in as `hermes@` directly.
- **Login**: only the YubiKey key in `server-base` logs in, as `augusto` or `hermes`; `authorizedKeysInHomedir` is off, so a key dropped into `~/.ssh/authorized_keys` is ignored. The agent key signs and pushes Git there but never logs in. Port 22 is the only open port; there is no public Hermes listener.
- **Clients**: the `security` aspect gives laptop and macmini an `ssh vps-hermes` match block that forwards the local gpg-agent extra socket (the supervised agent's socket-unit path, not `gpg-agent.conf`'s `extra-socket`) to the VPS's `/run/user/1000/gnupg/S.gpg-agent`, where `user-server`'s `gpg` uses it; the VPS runs no gpg-agent. `user-server` creates that directory, and `StreamLocalBindUnlink` replaces a stale socket. Set the block's `hostname` once the VPS has an address. Home Manager owns `~/.ssh/config` on both clients; an unmanaged file found at activation moves to `config.hm-bak`.
- **Hermes Desktop** reaches the gateway through its native SSH connection as `hermes@`, added in the app on each client; that user gets no gpg forwarding. It connects only while the YubiKey is plugged in.
- **Boot and disk**: disko lays out EF02 plus an ESP for hybrid BIOS/UEFI GRUB and an ext4 root. Confirm `/dev/sda` in the rescue system first.
- **Networking**: networkd with DHCP IPv4. Hetzner assigns IPv6 statically: add the server's `/64` address and `fe80::1` gateway in `vps-hermes.nix` after provisioning.
- **Secrets**: `hermes` decrypts its own file, `modules/hardware/vps-hermes/secrets.yaml`, holding only `github_token` and `agent_ssh_key`, never the shared `env.yaml`. vps-hermes does not build until that file exists, because sops-nix checks declared keys at build time; create it with the YubiKey (`sops modules/hardware/vps-hermes/secrets.yaml`, its `.sops.yaml` rule encrypts to the YubiKey). One age key at `/var/lib/sops-nix/key.txt` serves NixOS and `hermes`'s Home Manager sops, owned by `hermes`. Generate it after provisioning, add its public key to that rule and run `sops updatekeys` on the file. Until then the Hermes Git agent, wiki sync and `gh` token fail.
- **gpg as augusto** uses the forwarded YubiKey but needs the public key once: `gpg --fetch-keys https://keys.openpgp.org/vks/v1/by-fingerprint/7D8396F74725A208D835CE3730E62A1E4F078650`.
- **Runtime setup by hand**, as `hermes`: Claude (`claude`) and Codex logins, chat channels (`hermes gateway setup`), and repository checkouts in `~/dev`.

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

# Install the VPS from the Hetzner rescue system (confirm the disk first)
nix run github:nix-community/nixos-anywhere -- --flake .#vps-hermes root@<address>

# Deploy the VPS, built on the laptop
nixos-rebuild switch --flake .#vps-hermes --target-host augusto@<address> --sudo

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

# Update omp, terminal-browser and Herdr together
nix flake update llm-agents
```

`update-system` pin handling needs `nix-update` from the dev shell and reports per-pin failures in its final summary. HA pins are built after updating. The Ollama pin updates only its source; on Darwin it also builds `ollama-bin`, and on Linux Darwin build and runtime verification remain outstanding. Pin updates neither activate services nor change model tags.

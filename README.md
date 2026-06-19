# Personal NixOS Configuration

Dendritic NixOS configuration using [Den](https://github.com/vic/den) + [flake-parts](https://flake.parts) + [flake-file](https://github.com/vic/flake-file).

## Hosts

| Host | Platform | Profile | Description |
|------|----------|---------|-------------|
| `laptop` | x86_64-linux | workstation | Hyprland desktop with DMS shell |
| `macmini` | darwin | workstation | MacMini desktop |

## Building the NixOs Installer ISO

```bash
nix build .#installer
```

## Installing NixOS

### Option A: Remote install with nixos-anywhere

From an existing machine, targeting a machine booted with the custom ISO (or any Linux with SSH):

```bash
# 1. Boot target machine with ISO, note its IP

# 2. Prepare extra-files
EXTRA=$(mktemp -d)
cp -r ~/nixos "$EXTRA/home/augusto/nixos"
mkdir -p "$EXTRA/etc/nixos/secrets"
read -s -p "Password: " PASS && echo
echo "$PASS" | mkpasswd -m yescrypt -s > "$EXTRA/etc/nixos/secrets/augusto-password"

# 3. Install WITHOUT auto-reboot
nixos-anywhere --flake ~/nixos#laptop \
  --target-host root@<target-ip> \
  --extra-files "$EXTRA" \
  --chown /home/augusto 1000:100 \
  --phases kexec,disko,install

# 4. Run post-install via nixos-enter
ssh root@<target-ip>
nixos-enter --root /mnt -- fish /etc/post-install.fish --tpm --fido --sops --git-init

# 5. Reboot
reboot
```

The `--extra-files` flag copies the repo to the target. Use `--git-init` in the
post-install script to restore git history from the remote.

### Option B: Local install from the custom ISO

```bash
# 1. Boot the custom ISO

# 2. Install (formats disk, copies embedded repo, runs nixos-install)
install-local laptop

# 3. Run post-install for TPM/FIDO2 enrollment
sudo nixos-enter --root /mnt -- fish /etc/post-install.fish --tpm --fido --sops

# 4. Reboot
reboot
```

### Post-install flags

```
post-install.fish [FLAGS]

  --tpm          Enroll TPM2 for LUKS auto-unlock
  --fido         Enroll FIDO2 key(s) for LUKS unlock
  --fingerprint  Show fingerprint enrollment instructions
  --sops         Generate age key and configure sops-nix
  --dotfiles     Clone dotfiles repo to ~/nixos
  --media        Clone media repo to ~/media
  --git-init     Initialize git in ~/nixos (for --extra-files installs)
```

## Updating

```bash
# Full system rebuild
sudo nixos-rebuild switch --flake ~/nixos#laptop

# All flake inputs
nix flake update

# Neovim plugins only
update-neovim-plugins

# Firefox/Thunderbird extensions
update-firefox
update-thunderbird

# Regenerate flake.nix after changing module inputs
nix run .#write-flake
```

## Post Installation

### Fingerprint Enrollment

```fish
fprintd-enroll
fprintd-enroll -f right-index-finger
fprintd-enroll -f right-middle-finger
```

### Secrets Management

Secrets are managed using [sops-nix](https://github.com/Mic92/sops-nix) with age + GPG (YubiKey).

#### First-time setup on a new machine

```fish
nix-shell -p age sops yq-go --run "fish ~/nixos/modules/security/secrets/sops-setup.fish"
```

Cleanup some potential unused age keys from the `.sops.yaml` file.

#### Adding new secrets

```fish
sops ~/nixos/modules/security/secrets/env.yaml
```

Add the secret key to `modules/security/secrets/secrets.nix` and the environment variable to the template.

### FirefoxPWA (Progressive Web Apps)

PWAs are declared entirely in Nix via `programs.firefoxpwa` in
`modules/programs/firefox/firefox.nix`. The module writes
`~/.local/share/firefoxpwa/config.json` (a read-only Nix-store symlink), so PWAs
can no longer be added/removed through the firefoxpwa GUI or CLI — everything is
declarative. WhatsApp is configured as a working example.

#### Adding a PWA

1. Pick a unique site ULID (26 chars, `0123456789ABCDEFGHJKMNPQRSTVWXYZ`):

   ```fish
   nix run nixpkgs#ulid
   ```

1. Fetch the app icon hash (use the manifest's highest-res icon):

   ```fish
   nix-prefetch-url "<ICON_URL>" | xargs nix hash to-sri --type sha256
   ```

1. Add a `sites."<SITE_ULID>"` entry under the Default profile
   (`00000000000000000000000000`) in `programs.firefoxpwa`:

   ```nix
   sites."<SITE_ULID>" = {
     name = "MyApp";
     url = "https://example.com/";
     manifestUrl = "https://example.com/manifest.json";
     desktopEntry = {
       icon = pkgs.fetchurl {
         url = "<ICON_URL>";
         hash = "<SRI_HASH>";
       };
       categories = ["Network"];
     };
     settings.config = {
       icon_url = "<ICON_URL>";
       categories = ["social"];
     };
   };
   ```

#### Hiding the browser toolbar

Per-profile `user.js` prefs and `chrome/userChrome.css` are declared via
`home.file` against the Default profile path in `firefox.nix` — no manual steps.
The CSS hides `#titlebar`, `#nav-bar`, and `#TabsToolbar` so the PWA looks like a
native app window. Adjust those declarations to change the chrome.

#### Auto-launching on login

Add to the `exec-once` section in `modules/desktop/hyprland.nix`:

```nix
"uwsm app -- firefoxpwa site launch <SITE_ULID>"
```

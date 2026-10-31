---
name: sops-secrets
description: Add, change or expose a secret in this repo with sops-nix. Use when adding an API key, token or password, editing modules/security/secrets/env.yaml, or giving a program or service access to a secret.
---

# Secrets with sops-nix

All secrets live encrypted in `modules/security/secrets/env.yaml`. Git only ever holds ciphertext, and the Nix store only holds placeholders.

`.sops.yaml` lists the recipients: one age key per host plus the YubiKey GPG master key. Any host decrypts with its own age key. Re-encrypting needs the YubiKey.

## 1. Add the value

Ask the user to run `sops modules/security/secrets/env.yaml` and add `<key>: <value>`. sops re-encrypts on save. Keep secret values out of the chat, files and commands you run.

Done when the user confirms the key exists. `sops -d --extract '["<key>"]'` is not a check to run: it prints the value.

## 2. Declare it where it is used

Pick the level of the consumer:

- **User shell or user programs**: add `<key> = {};` to `sops.secrets` in `modules/security/secrets/secrets.nix` (the Home Manager `secrets` aspect). To export it, add `set -gx <VAR> ${config.sops.placeholder.<key>}` to the `env-secrets.fish` template in the same file.
- **System services**: declare `sops.secrets.<key>` in the service module and read `config.sops.secrets.<key>.path` at runtime, as `modules/services/mosquitto.nix` does. macmini gets system-level sops from the `open-webui` aspect; raspi imports it in `modules/hardware/raspi/raspi.nix` (see [System](../../../docs/system.md)).

Pass the secret file path to the service. Never interpolate a secret's contents into a Nix string, plist or store path.

## 3. Build

Stage the changed paths by name and build each affected host. `sops-install-secrets` checks declared keys against `env.yaml` at build time, so a missing key fails here. Done when every affected host builds.

## New host

Run `sops-setup` on the new machine. It creates the age key, adds it to `.sops.yaml` and re-encrypts `env.yaml`, which needs the YubiKey.

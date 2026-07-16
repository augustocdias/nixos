---
name: sops-secrets
description: How to add and manage secrets in this repo with sops-nix (age + GPG/YubiKey). Use when adding an API key/token/secret, editing the encrypted env.yaml, or exposing a secret to a program.
---

# Secrets with sops-nix

Secrets live in `modules/security/secrets/`, encrypted with **sops-nix**. The
`secrets` aspect (`secrets.nix`) declares them and renders an env file the shell
sources. NEVER commit a plaintext secret.

## Keys (`.sops.yaml`)

Encryption recipients:
- `&nixos` / `&macmini` — per-machine **age** keys (each host decrypts its own).
- `&yubikey` — GPG master key (YubiKey), can decrypt anywhere.

`creation_rules` encrypt everything matching
`modules/security/secrets/*.ya?ml` to both age keys + the GPG key. When you add
a NEW machine, add its age public key here and re-encrypt.

## Add a new secret

1. **Edit the encrypted file** with sops (never edit ciphertext by hand):
   ```bash
   sops modules/security/secrets/env.yaml
   ```
   Add `my_new_key: the-secret-value`. sops re-encrypts on save.

2. **Declare it** in `modules/security/secrets/secrets.nix` under
   `sops.secrets`:
   ```nix
   my_new_key = {};
   ```

3. **Expose it** where needed. The pattern here renders a fish env file via
   `sops.templates."env-secrets.fish"` using
   `${config.sops.placeholder.my_new_key}`:
   ```nix
   set -gx MY_NEW_KEY ${config.sops.placeholder.my_new_key}
   ```
   Add a matching `set -gx` line to the template.

4. Rebuild to activate (`sudo nixos-rebuild switch --flake .` /
   `darwin-rebuild switch --flake .`).

## Consuming secrets

- Programs that read env vars (e.g. opencode's `{env:ANTHROPIC_API_KEY}`) get
  them from the sourced `env-secrets.fish`.
- Runtime secret files are materialized under the sops runtime dir
  (`%r/...`), not the nix store — the store only ever holds ciphertext +
  placeholders.

## Rules

- Plaintext secrets never touch git. Only the sops-encrypted `env.yaml` is
  committed.
- The GPG signing/decryption key is YubiKey-backed; decryption needs the key
  present (or the machine's age key).
- Bootstrap of a fresh machine's age key: see `sops-setup.fish` /
  `sops-setup`.

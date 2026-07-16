---
name: den-module
description: How to add or modify a module (aspect) in this Den/flake-parts NixOS+darwin config. Use when creating a new program/service module, declaring flake inputs, or wiring an aspect into a host or user.
---

# Adding a Den aspect (module) to this repo

This flake uses **Den** + **flake-parts** + **import-tree** + **flake-file**.
`import-tree ./modules` auto-imports every `.nix` file under `modules/`
(except `_`-prefixed ones) as a flake-parts module.

## 1. Where the file goes

- Multi-file program → directory: `modules/programs/<name>/<name>.nix`
  (aspect name matches the directory name).
- Single-file program → `modules/programs/<name>.nix`.
- Service → `modules/services/<name>.nix` (or a directory).
- `_`-prefixed files are NOT auto-imported — use for helpers imported manually.

## 2. Aspect skeleton

```nix
{den, ...}: {
  den.aspects.<name> = {
    # Pick the classes this aspect targets. Each block is optional.
    homeManager = {pkgs, lib, ...}: {
      programs.<name>.enable = true;
    };
    nixos = {pkgs, ...}: { /* system-level NixOS config */ };
    darwin = {pkgs, ...}: { /* nix-darwin config */ };

    includes = with den.aspects; [ /* other aspects this depends on */ ];
  };
}
```

Real minimal example: `modules/programs/git/git.nix`.

## 3. Declaring flake inputs (distributed)

Inputs are declared **per module**, not in `flake.nix`. In the module:

```nix
{
  flake-file.inputs.<input-name> = {
    url = "github:owner/repo";
    # inputs.nixpkgs.follows = "nixpkgs";  # when applicable
  };
}
```

After changing any input declaration, **regenerate `flake.nix`**:

```bash
nix run .#write-flake
```

## 4. Wiring the aspect into a host/user

An aspect does nothing until something includes it. User-level aspects go into
the user aspect chain:

- Cross-platform (must build on BOTH nixos and darwin) → add to
  `den.aspects.user-base.includes` in `modules/user/base.nix`.
- Linux-only → `modules/user/linux.nix` (`user-linux`).
- macOS-only → `modules/user/mac.nix` (`user-macos`).

System/hardware aspects are included by the host definitions
(`modules/hosts.nix`) or the hardware profiles.

## 5. Conventions

- Format with **alejandra**: `nix run nixpkgs#alejandra -- <file>`.
- Theme is Catppuccin Mocha across the system — match it.
- Don't commit plaintext secrets (see the `sops-secrets` skill).

## 6. Validate

```bash
# stage new files so the flake sees them, then eval/build:
git add -A
nix eval .#nixosConfigurations.laptop.config.system.build.toplevel.drvPath
# full build (catches HM module assertions):
nix build .#nixosConfigurations.laptop.config.system.build.toplevel --no-link
```

Apply with `sudo nixos-rebuild switch --flake .` (laptop) or
`darwin-rebuild switch --flake .` (macmini).

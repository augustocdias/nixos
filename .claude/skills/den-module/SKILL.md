---
name: den-module
description: Add or change a Den aspect in this repo. Use when creating a program or service module, declaring a flake input, or wiring an aspect into a host or user.
---

# Den aspect

AGENTS.md owns file placement and formatting. This skill covers writing the aspect, wiring it, and proving it builds.

## 1. Write the aspect

```nix
{den, ...}: {
  den.aspects.<name> = {
    homeManager = {pkgs, ...}: { };
    nixos = {pkgs, ...}: { };
    darwin = {pkgs, ...}: { };
    includes = with den.aspects; [ ];
  };
}
```

Keep only the classes the aspect targets. `modules/services/podman.nix` is a minimal NixOS-only example; `modules/programs/git/git.nix` is a Home Manager one.

Done when the file defines `den.aspects.<name>` with only the classes it needs.

## 2. Declare inputs

Put each input in the module that uses it:

```nix
flake-file.inputs.<input> = {
  url = "github:owner/repo";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then run `nix run .#write-flake`. Done when the generated `flake.nix` contains the input.

## 3. Wire it in

An aspect applies only when something includes it.

- User aspects: add to `includes` of `user-base` (`modules/user/base.nix`, must build on Linux and Darwin), `user-linux` (`modules/user/linux.nix`) or `user-macos` (`modules/user/mac.nix`).
- System aspects: include from the host aspect named in `modules/hosts.nix` (`laptop`, `macmini`, `raspi`). `raspi` has no Home Manager user, so `homeManager` blocks never reach it.

Done when every host that should get the aspect reaches it through an `includes` chain.

## 4. Build every affected host

Flakes ignore untracked files. Stage the new paths by name (`git add <paths>`), never the whole tree. Then build each host the aspect reaches:

```bash
nix build .#nixosConfigurations.laptop.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.raspi.config.system.build.toplevel --no-link
nix eval .#darwinConfigurations.macmini.config.system.build.toplevel.drvPath
```

Use `nix eval` for macmini from Linux, since the laptop cannot build Darwin derivations. Done when every affected host builds or evaluates without errors.

Activation needs root and runs outside the agent jail. Hand the user the rebuild or deploy command from [System](../../../docs/system.md#common-operations).

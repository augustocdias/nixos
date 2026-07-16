---
name: nvim-plugin
description: How to add or configure a Neovim plugin in this repo — flake input, build strategy, and lze lazy-loading lua config. Use when adding an nvim plugin, changing its build, or writing its plugin config.
---

# Adding a Neovim plugin

Plugins are flake inputs (prefixed `nvim-`), built with nix, and lazy-loaded
with **lze** (BirdeeHub/lze). Config lives in
`modules/programs/neovim/configs/` (symlinked live into `~/.config/nvim`, so
lua changes need no rebuild — only the flake input + build wiring do).

## 1. Declare the flake input

In `modules/programs/neovim/neovim.nix`, add to `flake-file.inputs` using one
of the two helpers:

```nix
# source-only (flake = false), built via vimUtils.buildVimPlugin — MOST plugins:
nvim-<name> = mkPlugin "github:author/repo";

# full flake with a prebuilt package output (packages.<system>.default):
nvim-<name> = mkFlakePlugin "github:author/repo";
```

The input name MUST be `nvim-<name>` (the prefix enables
`nix flake update nvim-*` / the `update-nvim` script for selective updates).

## 2. Register build metadata

In `modules/programs/neovim/_plugins.nix`, add an entry to `pluginMeta`:

```nix
<name> = {};                      # default: buildVimPlugin from source
<name> = {useFlakePackage = true;};  # use the flake's prebuilt package
<name> = {lazy = false;};         # load eagerly (default is lazy via lze)
```

(`getInput` maps `<name>` → the `nvim-<name>` input automatically.)
Custom Rust builds (like codesnap) are the rare exception — follow the existing
pattern in `_plugins.nix`.

## 3. Regenerate flake.nix

```bash
nix run .#write-flake
```

## 4. Write the lua config (lze spec)

Add `modules/programs/neovim/configs/lua/plugins/<name>.lua` returning an lze
spec. Lazy-load via `event` / `cmd` / `keys` / `ft`:

```lua
return {
  "<name>",                    -- must match the pluginMeta key
  event = "DeferredUIEnter",   -- or cmd = {...}, keys = {...}, ft = {...}
  after = function()
    require("<name>").setup({ ... })
  end,
}
```

Look at neighbours in `configs/lua/plugins/` for the exact conventions
(keybinding groups, which-key registration, etc.). Format lua with **stylua**
(spaces, single quotes).

## 5. Apply

Input/build changes need a rebuild (`sudo nixos-rebuild switch --flake .`).
Pure lua edits are picked up on next Neovim launch (live symlink).

## Notes

- Neovim runs the **nightly overlay** (currently pinned — see the FIXME in
  `neovim.nix`).
- LSP/formatter/linter sets are documented in the repo AGENTS.md; add servers
  there if the plugin needs one.

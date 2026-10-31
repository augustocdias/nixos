---
name: nvim-plugin
description: Add or configure a Neovim plugin in this repo. Use when adding a plugin, changing how one builds or loads, or writing its Lua config.
---

# Neovim plugin

Each plugin is a flake input named `nvim-<name>`, built by Nix and lazy-loaded with lze. Read [Neovim](../../../docs/neovim.md) first.

## 1. Declare the input

In `flake-file.inputs` of `modules/programs/neovim/neovim.nix`:

```nix
nvim-<name> = mkPlugin "github:author/repo";       # source only, built with buildVimPlugin
nvim-<name> = mkFlakePlugin "github:author/repo";  # flake with packages.<system>.default
```

Use `mkFlakePlugin` only when the repo ships a flake package. The `nvim-` prefix is what `update-nvim` and `getInput` match on.

## 2. Register it

Add an entry to `pluginMeta` in `modules/programs/neovim/_plugins.nix`. The key is `<name>` without the prefix.

```nix
<name> = {};                          # buildVimPlugin from source, lazy
<name> = {useFlakePackage = true;};   # the flake's prebuilt package
<name> = {lazy = false;};             # load at startup
```

## 3. Regenerate the flake

Run `nix run .#write-flake`. Done when `flake.nix` lists `nvim-<name>`.

## 4. Write the lze spec

Create `modules/programs/neovim/configs/lua/plugins/<name>.lua`. The first field must equal the `pluginMeta` key. Load on `event`, `cmd`, `keys` or `ft`:

```lua
return {
    '<name>',
    cmd = { 'Command' },
    after = function()
        require('<name>').setup({})
    end,
}
```

Copy the key-group and which-key conventions from neighbouring specs. Format with StyLua.

## 5. Build

Stage the changed paths by name, then build the laptop:

```bash
nix build .#nixosConfigurations.laptop.config.system.build.toplevel --no-link
```

Done when the build passes. Input and `pluginMeta` changes need the user to rebuild. Lua edits take effect on the next Neovim start, because `configs/` is symlinked live.

Plugin updates run through `update-nvim`. Agent bash rules deny it, so ask the user to run it.

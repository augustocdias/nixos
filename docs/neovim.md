# Neovim reference

Use the `nvim-plugin` skill for plugin wiring. The aspect is `modules/programs/neovim/neovim.nix`.

## Neovim

### Architecture

- Neovim is the nightly build from the `neovim-nightly-overlay` input.
- `modules/programs/neovim/configs/` is symlinked to `~/.config/nvim` with `mkOutOfStoreSymlink`. Lua edits take effect on restart, without a rebuild.
- Plugins load lazily through `lze` (BirdeeHub/lze), a lazy-loading library without package management. Plugin specs live in `configs/lua/plugins/<name>.lua` and use `lze` fields (`event`, `cmd`, `keys`, `ft`).

### Plugins

Every plugin is a flake input named `nvim-<name>`, declared in `neovim.nix` with one of two helpers:

- `mkPlugin "github:author/repo"` is source-only (`flake = false`) and builds with `vimUtils.buildVimPlugin`.
- `mkFlakePlugin "github:author/repo"` uses the flake's `packages.${system}.default`.

A plugin also needs an entry in `pluginMeta` in `_plugins.nix`, keyed by `<name>`. Set `useFlakePackage = true` there to use the flake's package, and `lazy = false` for plugins loaded eagerly.

Update all plugins with `update-nvim`, which runs `nix flake update` on every `nvim-*` input. Agent bash rules deny `update-nvim`, so ask the user to run it.

### LSP, formatters, and linters

Each tool needs its binary in `extraPackages` in `neovim.nix` and its setup in Lua:

- LSP servers: `configs/lua/plugins/lspconfig.lua`. Rust goes through rustaceanvim in `rustacean.lua`.
- Formatters: `conform.lua`. TypeScript formatting comes from prettier, so the `tsc` server has formatting disabled.
- Linters: `nvim-lint.lua`.

### Keybinding philosophy

- Leader is Space; local leader is `\`.
- Mappings live in `configs/lua/utils/keymaps.lua` and group by mnemonic prefix (for example `<leader>l` LSP, `<leader>g` Git, `<leader>a` AI). Follow an existing group when adding a mapping.
- Directional mappings use hjkl.
- `<C-h/j/k/l>` in normal and insert mode moves between Neovim windows. At an edge, a Core-launched Neovim calls Herdr App's `pane.navigate` with its terminal ID. The App verifies focus before moving to a neighboring pane. Outside Core, movement remains within Neovim. Failed App requests produce a warning.
- The system clipboard is not synced (`clipboard = ''`). Visual-mode `<leader>c` copies to it explicitly.

### Agents and the editor

`configs/init.lua` gives each Neovim process a PID-named server socket; Godot projects retain their fixed socket name. The agent jail does not bind these sockets, so agents cannot drive the editor.

### Custom features

- `plugins/plugin-updates.lua` parses `flake.lock`, queries GitHub for each `nvim-*` input, and shows a startup dashboard of pending commits.
- `gatekeeper.nvim` (the author's plugin) makes buffers outside the working directory read-only.
- `utils/custom_fold.lua` renders fold text with treesitter highlighting.
- The theme is chosen by `vim.g.theme` in `init.lua` (Catppuccin or Tokyo Night).

## Editing guidelines

Format Lua with `stylua`.

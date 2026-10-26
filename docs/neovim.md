# Neovim reference

Read before changing the editor, plugins, builds, LSP servers, formatters, or linters. Use the `nvim-plugin` skill for plugin wiring. Source files remain authoritative for current values.

## Neovim

### Architecture

- **Nightly build** via the rolling `neovim-nightly-overlay` input, resolved by `flake.lock`
- **50+ plugins** managed as flake inputs with `nvim-` prefix and built with nix
- **Plugin loader**: `lze` (BirdeeHub/lze) — lazy.nvim alternative focused only on lazy loading instead of package management
- **Config location**: `modules/programs/neovim/configs/` symlinked to `~/.config/nvim` via `mkOutOfStoreSymlink` for live editing without rebuild
- **Plugin build**: `_plugins.nix` provides `buildPlugin` with three strategies: source-only (most plugins), flake package (lze, blink-cmp, rustaceanvim), custom Rust build (codesnap)

### Plugin management

Two helper functions declare flake inputs:

- `mkPlugin "github:author/repo"` — source-only (`flake = false`), built via `vimUtils.buildVimPlugin`
- `mkFlakePlugin "github:author/repo"` — full flake, uses pre-built `packages.${system}.default`

To update all neovim plugins: `nix flake update nvim-*` or run the `update-nvim` script.

### LSP servers

| Server        | Language      | Notes                                                                                                       |
| ------------- | ------------- | ----------------------------------------------------------------------------------------------------------- |
| rust-analyzer | Rust          | Via rustaceanvim, clippy on save, nightly rustfmt                                                           |
| tsc           | TypeScript/JS | Go-based native LSP (`typescript` 7.x, formerly `typescript-go`), formatting disabled (prettier handles it) |
| nixd          | Nix           |                                                                                                             |
| emmylua_ls    | Lua           | Workspace includes all plugin paths                                                                         |
| bashls        | Bash          |                                                                                                             |
| yamlls        | YAML          | SchemaStore integration                                                                                     |
| jsonls        | JSON          | SchemaStore integration                                                                                     |
| eslint        | JS/TS         | Also used as linter                                                                                         |
| taplo         | TOML          |                                                                                                             |
| harper_ls     | Grammar       | Checks prose in comments                                                                                    |
| docker LSPs   | Docker        | dockerfile + compose                                                                                        |
| qmlls         | QML           | For Quickshell/DMS development                                                                              |
| gdscript      | GDScript      | Godot engine                                                                                                |

### Formatters (conform.nvim)

CSS/HTML/JS/TS/JSON/YAML: prettier | Lua: stylua | Nix: alejandra | Python: black | Shell: shfmt | SQL: sqlfluff | Markdown: markdownlint | Rust: rustfmt (via rust-analyzer, nightly)

### Linters (nvim-lint)

Dockerfile: hadolint | JS/TS: eslint | Lua: selene | Markdown: markdownlint + write_good + codespell | Nix: statix + deadnix | YAML: yamllint + actionlint

### Keybinding philosophy

- **Leader**: Space. **Local leader**: `\`
- **Vim-centric**: modal editing, motions enhanced (flash, treesitter textobjects)
- **Mnemonic groups**: `<leader>l` LSP, `<leader>g` Git, `<leader>h` Gitsigns, `<leader>r` Rust, `<leader>t` Trouble, `<leader>p` search/grep, `<leader>v` Vim internals, `<leader>a` AI
- **Herdr integration**: `<C-h/j/k/l>` moves between Neovim splits and falls through to herdr panes at edges. Hand-rolled in `utils/keymaps.lua` (`mux_move`), not a plugin: it runs `wincmd <dir>` and, when the window did not change, calls `herdr pane focus --direction <dir> --pane $HERDR_PANE_ID`. Outside herdr the fallthrough is a no-op.
- **No arrow key dependency**: `<C-h/j/k/l>` provides cursor movement in insert/command mode
- **Clipboard isolation**: system clipboard NOT synced by default; `<leader>c` in visual mode copies explicitly

### AI integration

The agent harness (omp for personal work; Claude Code or omp for work) runs in its own herdr pane next to Neovim. There is no editor MCP any more (the nvim-mcp server was removed), and the agent jail does not bind Neovim's socket (`~/.cache/nvim/server-<HERDR_WORKSPACE_ID>.pipe`), so agents cannot reach the editor.

### Notable custom features

- **Plugin Update Checker** (`plugin-updates.lua`): 569-line module that parses `flake.lock`, queries GitHub for each `nvim-*` input, shows a live-updating dashboard with commit diffs at startup
- **Gatekeeper** (`augustocdias/gatekeeper.nvim`): author's own plugin that makes buffers outside CWD readonly
- **Treesitter-aware fold text**: custom fold rendering preserving syntax highlighting
- **Dual theme support**: Catppuccin (default) and Tokyo Night, switchable via one line in `init.lua`

## Editing guidelines

- **Lua files**: Format with `stylua`. Follow `plugins/<name>.lua` pattern for new plugin configs. Use `lze` spec format (event, cmd, keys, ft for lazy loading).

-- Register LzeStatus command
vim.api.nvim_create_user_command('LzeStatus', function ()
    require('utils.lze').show_status()
end, { desc = 'Show lze plugin status' }
)

return {
    -- stylua: ignore
    { import = 'plugins.autopairs' },
    { import = 'plugins.autosession' },
    { import = 'plugins.catppuccin' },
    { import = 'plugins.cmp' },
    { import = 'plugins.codesnap' },
    { import = 'plugins.diffview' },
    { import = 'plugins.dropbar' },
    { import = 'plugins.flash' },
    { import = 'plugins.gatekeeper' },
    { import = 'plugins.gitsigns' },
    { import = 'plugins.gx' },
    { import = 'plugins.helpview' },
    { import = 'plugins.lspconfig' },
    { import = 'plugins.lualine' },
    { import = 'plugins.markdown' },
    { import = 'plugins.matchup' },
    { import = 'plugins.mini-ai' },
    { import = 'plugins.mini-files' },
    { import = 'plugins.mini-move' },
    { import = 'plugins.mini-surround' },
    { import = 'plugins.noice' },
    { import = 'plugins.conform' },
    { import = 'plugins.nvim-lint' },
    { import = 'plugins.octo' },
    { import = 'plugins.plugin-updates' },
    { import = 'plugins.rustacean' },
    { import = 'plugins.snacks' },
    { import = 'plugins.tabby' },
    { import = 'plugins.tabout' },
    { import = 'plugins.todo-comments' },
    { import = 'plugins.tokyonight' },
    { import = 'plugins.treesitter' },
    { import = 'plugins.trouble' },
    { import = 'plugins.undotree' },
    { import = 'plugins.utils' },
    { import = 'plugins.which-key' }
}

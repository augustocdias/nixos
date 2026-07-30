local pipe_suffix
if vim.g.godot then
    pipe_suffix = 'godot'
else
    pipe_suffix = os.getenv('HERDR_WORKSPACE_ID') or os.getenv('ZELLIJ_SESSION_NAME') or 'dettached'
end

local pipepath = vim.fn.stdpath('cache') .. '/server-' .. pipe_suffix .. '.pipe'
require('utils').start_server(pipepath)

vim.g.theme = 'catppuccin'
vim.g.flavours = {
    catppuccin = 'mocha', -- dark
    -- catppuccin = 'latte', -- light
    -- tokyonight = 'day', -- light
    tokyonight = 'night', -- dark
}
vim.g.flavour = vim.g.flavours[vim.g.theme]

require('utils.logger').setup()

require('utils.custom_fold')
require('settings.general')
require('settings.gui')
require('settings.neovide')
require('utils.keymaps').map_keys()
require('utils.autocommands').setup()
require('lze').load('plugins')

vim.cmd('colorscheme ' .. vim.g.theme .. '-' .. vim.g.flavour)

-- formatters
return {
    'conform',
    event = 'BufWritePre',
    cmd = 'ConformInfo',
    after = function()
        require('conform').setup({
            formatters_by_ft = {
                css = { 'prettier' },
                fish = { 'fish_indent' },
                html = { 'prettier' },
                javascript = { 'prettier' },
                javascriptreact = { 'prettier' },
                json = { 'prettier' },
                lua = { 'stylua' },
                markdown = { 'mdformat' },
                nix = { 'alejandra' },
                python = { 'black' },
                rust = { 'rustfmt', lsp_format = 'fallback' },
                sh = { 'shfmt' },
                sql = { 'sqlfluff' },
                typescript = { 'prettier' },
                typescriptreact = { 'prettier' },
                yaml = { 'prettier' },
            },
            default_format_opts = {
                lsp_format = 'fallback',
            },
            format_on_save = function(bufnr)
                if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                    return
                end
                return { timeout_ms = 500, lsp_format = 'fallback' }
            end,
            formatters = {
                stylua = {
                    prepend_args = { '--config-path', vim.fn.expand('~/.config/stylua.toml') },
                },
            },
        })
    end,
    keys = {
        {
            '<leader>lk',
            function()
                vim.b.disable_autoformat = not vim.b.disable_autoformat
                local state = vim.b.disable_autoformat and 'disabled' or 'enabled'
                vim.notify('Autoformat ' .. state .. ' for buffer')
            end,
            mode = { 'n' },
            desc = 'Toggle autoformat (buffer)',
            noremap = true,
        },
        {
            '<leader>lf',
            function()
                require('conform').format({ async = false, lsp_format = 'fallback' })
            end,
            mode = { 'n' },
            desc = 'Format code',
            silent = true,
        },
    },
}

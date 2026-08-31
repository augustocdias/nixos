return {
    lsp_autocmds = function(client, bufnr)
        local autocmd = vim.api.nvim_create_autocmd
        local augroup = function(name)
            return vim.api.nvim_create_augroup(name, { clear = false })
        end
        if client.server_capabilities.document_highlight or client.server_capabilities.documentHighlightProvider then
            local group = augroup('LSPHighlightSymbols')

            -- Highlight text at cursor position
            autocmd({ 'CursorHold', 'CursorHoldI' }, {
                desc = 'Highlight references to current symbol under cursor',
                buffer = bufnr,
                callback = vim.lsp.buf.document_highlight,
                group = group,
            })
            autocmd({ 'CursorMoved' }, {
                desc = 'Clear highlights when cursor is moved',
                buffer = bufnr,
                callback = vim.lsp.buf.clear_references,
                group = group,
            })
        end
        local group = augroup('LSPDianostics')
        autocmd({ 'CursorHold', 'CursorHoldI' }, {
            desc = 'Show box with diagnostics for current line',
            pattern = '*',
            callback = function()
                vim.diagnostic.open_float({ focusable = false })
            end,
            group = group,
        })
    end,
    setup = function()
        local autocmd = vim.api.nvim_create_autocmd
        local augroup = function(name)
            return vim.api.nvim_create_augroup(name, { clear = true })
        end

        autocmd({ 'BufRead' }, {
            desc = "Prevent accidental writes to buffers that shouldn't be edited",
            pattern = '*.orig',
            command = 'set readonly',
        })

        autocmd({ 'TextYankPost' }, {
            desc = 'Highlight yanked text',
            pattern = '*',
            callback = function()
                vim.hl.hl_op({ higroup = 'IncSearch', timeout = 1000 })
            end,
        })

        autocmd({ 'BufReadPost' }, {
            group = augroup('LastPlace'),
            pattern = { '*' },
            desc = 'When editing a file, always jump to the last known cursor position',
            callback = function()
                local exclude = { 'gitcommit', 'commit', 'gitrebase' }
                if vim.tbl_contains(exclude, vim.bo.filetype) then
                    return
                end
                local line = vim.fn.line('\'"')
                if line >= 1 and line <= vim.fn.line('$') then
                    vim.cmd('normal! g`"')
                end
            end,
        })
    end,
}

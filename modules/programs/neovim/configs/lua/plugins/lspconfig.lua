-- collection of LSP configurations for nvim
return {
    {
        'SchemaStore', -- adds schemas for json lsp
        dep_of = 'nvim-lspconfig',
    },
    {
        'lightbulb', -- adds sign for code actions in sign column
        after = function()
            require('nvim-lightbulb').setup({
                autocmd = { enabled = true },
                sign = { text = '󰛩' },
            })
        end,
    },
    {
        'nvim-lspconfig',
        priority = 100,
        lazy = false,
        after = function()
            local lsp_utils = require('utils.lsp')

            -- general LSP config
            vim.diagnostic.config({
                underline = true,
                virtual_text = false,
                severity_sort = true,
                update_in_insert = true,
                signs = {
                    text = {
                        [vim.diagnostic.severity.ERROR] = '',
                        [vim.diagnostic.severity.WARN] = '',
                        [vim.diagnostic.severity.INFO] = '',
                        [vim.diagnostic.severity.HINT] = '',
                    },
                    numhl = {
                        [vim.diagnostic.severity.ERROR] = 'DiagnosticSignError',
                        [vim.diagnostic.severity.WARN] = 'DiagnosticSignWarn',
                        [vim.diagnostic.severity.INFO] = 'DiagnosticSignInfo',
                        [vim.diagnostic.severity.HINT] = 'DiagnosticSignHint',
                    },
                },
            })

            vim.lsp.on_type_formatting.enable()

            -- bash
            vim.lsp.enable('bashls')
            vim.lsp.config('bashls', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
            })
            -- yaml
            vim.lsp.enable('yamlls')
            vim.lsp.config('yamlls', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
                settings = {
                    yaml = {
                        schemaStore = {
                            enable = false,
                            url = 'https://www.schemastore.org/api/json/catalog.json',
                        },
                        schemas = require('schemastore').yaml.schemas(),
                        format = {
                            enable = true,
                        },
                    },
                },
            })
            -- json
            vim.lsp.enable('jsonls')
            vim.lsp.config('jsonls', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
                settings = {
                    json = {
                        schemas = require('schemastore').json.schemas(),
                        validate = { enable = true },
                    },
                },
            })
            -- docker
            vim.lsp.enable('docker_language_server')
            vim.lsp.config('docker_language_server', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
            })
            vim.lsp.enable('docker_compose_language_service')
            vim.lsp.config('docker_compose_language_service', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
            })
            -- toml
            vim.lsp.enable('taplo')
            vim.lsp.config('taplo', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
            })
            -- harper (grammar checker)
            vim.lsp.enable('harper_ls')
            vim.lsp.config('harper_ls', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
            })

            -- godot
            vim.lsp.enable('gdscript')
            vim.lsp.config('gdscript', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
            })

            -- lua
            local function get_plugin_paths()
                local paths = {}
                local pack_dir = vim.fn.stdpath('data') .. '/site/pack/hm'
                for _, dir in ipairs({ pack_dir .. '/opt', pack_dir .. '/start' }) do
                    vim.list_extend(paths, vim.fn.glob(dir .. '/*', false, true))
                end
                table.insert(paths, vim.env.VIMRUNTIME)
                return paths
            end

            vim.lsp.enable('emmylua_ls')
            vim.lsp.config('emmylua_ls', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
                settings = {
                    emmylua = {
                        runtime = {
                            version = 'LuaJIT',
                            requirePattern = {
                                'lua/?.lua',
                                'lua/?/init.lua',
                                '?/lua/?.lua',
                                '?/lua/?/init.lua',
                            },
                        },
                        workspace = {
                            library = get_plugin_paths(),
                        },
                    },
                },
            })

            -- nix
            vim.lsp.enable('nixd')
            vim.lsp.config('nixd', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
            })

            -- typescript (tsgo - native Go LSP)
            vim.lsp.enable('tsgo')
            vim.lsp.config('tsgo', {
                on_attach = function(client, bufnr)
                    lsp_utils.on_attach(client, bufnr)
                    client.server_capabilities.documentFormattingProvider = false
                    client.server_capabilities.documentRangeFormattingProvider = false
                end,
                capabilities = lsp_utils.capabilities(),
                settings = {
                    typescript = {
                        inlayHints = {
                            parameterNames = {
                                enabled = 'all',
                                suppressWhenArgumentMatchesName = false,
                            },
                            parameterTypes = { enabled = true },
                            variableTypes = { enabled = true },
                            propertyDeclarationTypes = { enabled = true },
                            functionLikeReturnTypes = { enabled = true },
                            enumMemberValues = { enabled = true },
                        },
                    },
                },
            })

            -- quickshell
            vim.lsp.enable('qmlls')
            vim.lsp.config('qmlls', {
                on_attach = lsp_utils.on_attach,
                capabilities = lsp_utils.capabilities(),
            })
        end,
        keys = {
            {
                'gD',
                vim.lsp.buf.declaration,
                mode = { 'n' },
                desc = 'Go to declaration',
                silent = true,
            },
            {
                'gt',
                vim.lsp.buf.type_definition,
                mode = { 'n' },
                desc = 'Go to type definition',
                silent = true,
            },
            {
                'gd',
                vim.lsp.buf.definition,
                mode = { 'n' },
                desc = 'Go to definition',
                silent = true,
            },
            {
                'gw',
                ':vsplit | lua vim.lsp.buf.definition()<CR>',
                mode = { 'n' },
                desc = 'Go to definition',
                silent = true,
            },
            {
                'gi',
                vim.lsp.buf.implementation,
                mode = { 'n' },
                desc = 'Go to implementation',
                silent = true,
            },
            {
                'gr',
                function()
                    vim.lsp.buf.references({ includeDeclaration = false })
                end,
                mode = { 'n' },
                desc = 'Find references',
                silent = true,
            },
            {
                '<M-s>',
                vim.lsp.buf.signature_help,
                mode = { 'i' },
                desc = 'Signature help',
                silent = true,
            },
            {
                '<M-s>',
                vim.lsp.buf.signature_help,
                mode = { 'n' },
                desc = 'Signature help',
                silent = true,
            },
            {
                '<leader>la',
                '<cmd>lua vim.lsp.buf.code_action()<CR>',
                mode = { 'n' },
                desc = 'Code actions',
                noremap = true,
            },
            {
                '<leader>lb',
                vim.diagnostic.open_float,
                mode = { 'n' },
                desc = 'Show line diagnostics',
                noremap = true,
            },
            {
                '<leader>lc',
                function()
                    vim.lsp.codelens.enable(not vim.lsp.codelens.is_enabled({ bufnr = 0 }), { bufnr = 0 })
                end,
                mode = { 'n' },
                desc = 'Toggle CodeLens',
                noremap = true,
            },
            {
                '<leader>ll',
                '<cmd>lua vim.lsp.codelens.run()<CR>',
                mode = { 'n' },
                desc = 'Code Lens',
                noremap = true,
            },
            {
                '<leader>lm',
                '<cmd>lua vim.lsp.buf.rename()<CR>',
                mode = { 'n' },
                desc = 'Rename symbol',
                noremap = true,
            },
            {
                '<leader>lq',
                vim.diagnostic.setloclist,
                mode = { 'n' },
                desc = 'Diagnostic set loclist',
                noremap = true,
            },
            {
                '<leader>la',
                '<cmd>lua vim.lsp.buf.code_action()<CR>',
                mode = { 'v' },
                desc = 'Code Action',
                noremap = true,
            },
        },
    },
}

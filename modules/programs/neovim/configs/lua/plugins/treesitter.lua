return {
    {
        'nvim-treesitter',
        lazy = false,
        dep_of = { 'nvim-treesitter-textobjects', 'nvim-treesitter-context' },
    }, -- enhancements in highlighting and virtual text
    {
        'nvim-treesitter-textobjects', -- adds treesitter based text objects
        lazy = false,
        before = function()
            vim.g.no_plugin_maps = true
        end,
        keys = {
            {
                'au',
                function()
                    require('nvim-treesitter-textobjects.select').select_textobject('@comment.outer')
                end,
                mode = { 'x', 'o' },
                desc = 'Select Treesitter Textobjects - Comment Outer',
                noremap = true,
            },
            {
                'iu',
                function()
                    require('nvim-treesitter-textobjects.select').select_textobject('@comment.inner')
                end,
                mode = { 'x', 'o' },
                desc = 'Select Treesitter Textobjects - Comment Inner',
                noremap = true,
            },
            {
                'af',
                function()
                    require('nvim-treesitter-textobjects.select').select_textobject('@function.outer')
                end,
                mode = { 'x', 'o' },
                desc = 'Select Treesitter Textobjects - Function Outer',
                noremap = true,
            },
            {
                'if',
                function()
                    require('nvim-treesitter-textobjects.select').select_textobject('@function.inner')
                end,
                mode = { 'x', 'o' },
                desc = 'Select Treesitter Textobjects - Function Inner',
                noremap = true,
            },
            {
                'ac',
                function()
                    require('nvim-treesitter-textobjects.select').select_textobject('@class.outer')
                end,
                mode = { 'x', 'o' },
                desc = 'Select Treesitter Textobjects - Class Outer',
                noremap = true,
            },
            {
                'ic',
                function()
                    require('nvim-treesitter-textobjects.select').select_textobject('@class.inner')
                end,
                mode = { 'x', 'o' },
                desc = 'Select Treesitter Textobjects - Class Inner',
                noremap = true,
            },
            {
                'ab',
                function()
                    require('nvim-treesitter-textobjects.select').select_textobject('@block.outer')
                end,
                mode = { 'x', 'o' },
                desc = 'Select Treesitter Textobjects - Block Outer',
                noremap = true,
            },
            {
                'ib',
                function()
                    require('nvim-treesitter-textobjects.select').select_textobject('@block.inner')
                end,
                mode = { 'n', 'x', 'o' },
                desc = 'Select Treesitter Textobjects - Block Inner',
                noremap = true,
            },
            {
                '[f',
                function()
                    require('nvim-treesitter-textobjects.move').goto_previous_start('@function.outer')
                end,
                mode = { 'n', 'x', 'o' },
                desc = 'Move Treesitter Textobjects - Function Previous Start',
                noremap = true,
            },
            {
                ']f',
                function()
                    require('nvim-treesitter-textobjects.move').goto_next_start('@function.outer')
                end,
                mode = { 'n', 'x', 'o' },
                desc = 'Move Treesitter Textobjects - Function Next Start',
                noremap = true,
            },
            {
                '[F',
                function()
                    require('nvim-treesitter-textobjects.move').goto_previous_end('@function.outer')
                end,
                mode = { 'n', 'x', 'o' },
                desc = 'Move Treesitter Textobjects - Function Previous End',
                noremap = true,
            },
            {
                ']F',
                function()
                    require('nvim-treesitter-textobjects.move').goto_next_end('@function.outer')
                end,
                mode = { 'n', 'x', 'o' },
                desc = 'Move Treesitter Textobjects - Function Next End',
                noremap = true,
            },
            {
                '[c',
                function()
                    require('nvim-treesitter-textobjects.move').goto_previous_start('@class.outer')
                end,
                mode = { 'n', 'x', 'o' },
                desc = 'Move Treesitter Textobjects - Class Previous Start',
                noremap = true,
            },
            {
                ']c',
                function()
                    require('nvim-treesitter-textobjects.move').goto_next_start('@class.outer')
                end,
                mode = { 'n', 'x', 'o' },
                desc = 'Move Treesitter Textobjects - Class Next Start',
                noremap = true,
            },
            {
                '[C',
                function()
                    require('nvim-treesitter-textobjects.move').goto_previous_end('@class.outer')
                end,
                mode = { 'n', 'x', 'o' },
                desc = 'Move Treesitter Textobjects - Class Previous End',
                noremap = true,
            },
            {
                ']C',
                function()
                    require('nvim-treesitter-textobjects.move').goto_next_end('@class.outer')
                end,
                mode = { 'n', 'x', 'o' },
                desc = 'Move Treesitter Textobjects - Class Next End',
                noremap = true,
            },
        },
        after = function()
            require('nvim-treesitter-textobjects').setup({
                select = {
                    lookahead = true,
                },
            })
        end,
    },
    {
        'nvim-treesitter-context', -- shows context of offscreen block in a float
        lazy = false,
        after = function()
            require('treesitter-context').setup({
                enable = true,
                max_lines = 3,
                mode = 'topline',
                patterns = {
                    default = {
                        'class',
                        'function',
                        'method',
                        'for',
                        'while',
                        'if',
                        'switch',
                        'case',
                    },
                    rust = {
                        'impl_item',
                        'struct',
                        'enum',
                    },
                    json = {
                        'pair',
                    },
                    yaml = {
                        'block_mapping_pair',
                    },
                },
            })
        end,
    },
}

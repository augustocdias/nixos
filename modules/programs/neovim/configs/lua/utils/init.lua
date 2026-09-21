return {
    noice_status_color = function(flavour)
        if vim.g.theme == 'catppuccin' then
            return require('catppuccin.palettes').get_palette(flavour)['teal']
        else
            return require('tokyonight.colors').setup({ style = flavour }).teal
        end
    end,

    command_status = function(color)
        return {
            function()
                return require('noice').api.status.command.get()
            end,
            cond = function()
                return require('noice').api.status.command.has()
            end,
            color = { fg = color },
        }
    end,

    -- Given a Rust target triple, return a descriptive hostname
    describe_host = function(target)
        local mappings = {
            ['x86_64-apple-darwin'] = ' Mac (Intel)',
            ['aarch64-apple-darwin'] = ' Mac (Apple Silicon)',
            ['x86_64-unknown-linux-gnu'] = ' Linux (x86_64)',
            ['aarch64-unknown-linux-gnu'] = ' Linux (ARM64)',
            ['x86_64-pc-windows-msvc'] = '  Windows (x86_64)',
            ['i686-pc-windows-msvc'] = '󰨡  Windows (32-bit)',
            ['x86_64-pc-windows-gnu'] = '  Windows (x86_64)',
            ['i686-pc-windows-gnu'] = '󰨡  Windows (32-bit)',
        }

        return mappings[target] or ('Unknown Host (' .. target .. ')')
    end,

    -- Returns rust's host target triple
    get_host_target = function()
        local cmd = "cargo -vV | grep 'host' | cut -d' ' -f2"
        local host = vim.fn.system(cmd):gsub('%s+', '') -- remove trailing newline/whitespace

        if vim.v.shell_error ~= 0 or host == '' then
            return nil, 'Failed to get cargo host'
        end

        return host
    end,

    start_server = function(pipepath)
        local alive = false
        if vim.uv.fs_stat(pipepath) then
            local ok, conn = pcall(vim.fn.sockconnect, 'pipe', pipepath)
            if ok and conn and conn > 0 then
                alive = true
                vim.fn.chanclose(conn)
            end
        end
        if not alive then
            vim.fn.delete(pipepath)
            vim.fn.serverstart(pipepath)
        end
    end,
}

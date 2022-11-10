local M = {}

function M.setup(config)
    -- Note, this would be kind of nice to be able to run as a command
    -- that takes a movement, but this doesn't seem to be supported by
    -- Lua at the moment
    vim.api.nvim_create_user_command('Contribtors',
        function(opts)
            local filename = vim.api.nvim_buf_get_name(0)
            local command = { 'sh', '-c',
                string.format([[git blame -L%s,%s --line-porcelain -- %s | \
                                grep -e "^author-mail" | sort | uniq -c | sort -rh]],
                    opts.line1, opts.line2, filename) }
            vim.fn.jobstart(command,
                {
                    on_stdout = function(_, output, _)
                        local scratch_buffer = vim.api.nvim_create_buf(false, true)
                        vim.api.nvim_buf_set_lines(scratch_buffer, 0, #output, false, output)
                        vim.api.nvim_open_win(scratch_buffer, false, {
                            relative = 'win',
                            width = 50,
                            height = #output,
                            row = 10,
                            col = 50,
                        })
                    end,
                    on_stderr = function(_, output, _)
                        if config.debug then
                            for _, line in ipairs(output) do
                                print(line)
                            end
                        end
                    end,
                    on_exit = function(_, err, _)
                        if err ~= 0 then
                            print('There was an error running git blame')
                        end
                    end,
                    stdout_buffered = true,
                    stderr_buffered = true,
                })
        end, {
        range = '%',
    })
end

return M

-- vim: set et ts=4 sw=4 ss=4 tw=100 :

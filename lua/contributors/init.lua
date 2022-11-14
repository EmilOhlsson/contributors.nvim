local M = {}


local function create_window()
    vim.api.nvim_command('botright vnew')
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_name(buf, 'Contributors')
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'filetype', 'nvim-contributors')
    vim.api.nvim_win_set_option(win, 'wrap', false)
    vim.api.nvim_win_set_option(win, 'cursorline', true)
    vim.api.nvim_win_set_option(win, 'relativenumber', false)
    vim.api.nvim_win_set_option(win, 'number', false)
    vim.api.nvim_win_set_width(win, 35)

    return win, buf
end

-- Run git blame on line range, and return a list of contributors
-- with line score and contact address for each contributor
local function get_contributors(file, l_start, l_end)
    local result = {}
    local command = { 'sh', '-c',
        string.format([[git blame -L%s,%s --line-porcelain -- %s | \
                        grep -e "^author-mail" | sort | uniq -c | sort -rh]],
            l_start, l_end, file) }

    -- Launch command, and populate result based on stdout output
    local id = vim.fn.jobstart(command,
        {
            -- Parse produced outptut, and store in result list
            on_stdout = function(_, output, _)
                for _, line in ipairs(output) do
                    local score, mail = string.match(line, "^%s*(%d+) author%-mail <(%g+)>")
                    if score and mail then
                        table.insert(result, { score = tonumber(score), contact = mail })
                    end
                end
            end,
            on_exit = function(_, err, _)
                if err ~= 0 then
                    print('There was an error running git blame')
                end
            end,
            -- Unless there is some mistake, output should be small,
            -- so might as well await all output to simplify parsing
            stdout_buffered = true,
            stderr_buffered = true,
        })
    -- If we didn't get any result within 3 seconds,
    -- then there was probably some error
    vim.fn.jobwait({ id }, 3000)
    return result
end

-- Fill buffer with contributors
local function display_contributors(buf, contributors)
    -- Temporarily allow modification
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)

    -- Transform contribtuors to something presentable
    local contrib_lines = {}
    for _, contrib in ipairs(contributors) do
        table.insert(contrib_lines, string.format("%s: %s", contrib.score, contrib.contact))
    end

    -- Clear, and write lines to buffer, and set as non-modifiable again
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(buf, 0, #contrib_lines, false, contrib_lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

function M.setup(config)
    -- Note, this would be kind of nice to be able to run as a command
    -- that takes a movement, but this doesn't seem to be supported by
    -- Lua at the moment
    vim.api.nvim_create_user_command('Contributors',
        function(opts)
            local file_name = vim.api.nvim_buf_get_name(0)

            -- Make sure there is a focues window and associated buffer
            -- to present contributors in. Also, file name must be read
            -- befor shifting focus, because we don't care about the
            -- contributor buffer itself
            if M.win and vim.api.nvim_win_is_valid(M.win) then
                vim.api.nvim_set_current_win(M.win)
            else
                M.win, M.buf = create_window()
            end

            -- Retrieve contributors for the range, and display list
            local contributors = get_contributors(file_name, opts.line1, opts.line2)
            display_contributors(M.buf, contributors)
        end, {
        -- Allow range input, and by default, take entire file
        range = '%',
    })
end

return M

-- vim: set et ts=4 sw=4 ss=4 tw=100 :

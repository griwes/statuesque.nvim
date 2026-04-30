--- @return statuesque.RenderFunction
return function()
    return function()
        local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
        return {
            role = 'location',
            text = ('%d:%d'):format(cursor[1], cursor[2] + 1),
        }
    end
end

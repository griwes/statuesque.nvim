--- @param opts? statuesque.WidgetIconOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    return function()
        local head = vim.b.gitsigns_head or vim.b.minidiff_summary_string
        if type(head) ~= 'string' or head == '' then
            return false
        end

        return {
            role = 'git-branch',
            text = (opts.icon or '') .. ' ' .. head,
            max_width = opts.max_width or 24,
            truncate = 'right',
        }
    end
end

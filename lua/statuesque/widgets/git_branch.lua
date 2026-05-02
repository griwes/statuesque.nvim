--- @param opts? statuesque.WidgetIconOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    return function(context)
        local ctx = require('statuesque.context')
        local head = ctx.buffer_var(context, 'gitsigns_head') or ctx.buffer_var(context, 'minidiff_summary_string')
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

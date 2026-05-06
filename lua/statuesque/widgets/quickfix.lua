--- @param opts? statuesque.WidgetQuickfixOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    local kind = opts.kind or opts.list or 'quickfix'
    local is_location = kind == 'location' or kind == 'loclist'
    local label = opts.label or (is_location and 'LL' or 'QF')

    return function(context)
        local info
        if is_location then
            local winid = require('statuesque.context').winid(context)
            info = vim.fn.getloclist(winid, { size = 0, idx = 0, title = 0 })
        else
            info = vim.fn.getqflist({ size = 0, idx = 0, title = 0 })
        end

        local size = tonumber(info.size) or 0
        if size == 0 then
            if opts.empty == true then
                return { role = 'quickfix', text = opts.empty_text or '' }
            end
            return false
        end

        local index = tonumber(info.idx) or 0
        local text = ('%s %d/%d'):format(label, index > 0 and index or 1, size)
        if opts.title == true and type(info.title) == 'string' and info.title ~= '' then
            text = text .. ' ' .. info.title
        end

        return {
            role = is_location and 'location-list' or 'quickfix',
            text = text,
            max_width = opts.max_width or 32,
            truncate = 'right',
            hl = opts.hl or 'StatuesqueWarning',
        }
    end
end

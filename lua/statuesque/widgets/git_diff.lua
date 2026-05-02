--- @class statuesque.WidgetGitDiffStatus
--- @field added? integer
--- @field changed? integer
--- @field removed? integer

--- @param opts? statuesque.WidgetGitDiffOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    local labels = opts.labels or {
        added = ' ',
        changed = ' ',
        removed = ' ',
    }
    local highlights = opts.highlights
        or {
            added = 'DiffAdd',
            changed = 'DiffChange',
            removed = 'DiffDelete',
        }

    return function(context)
        local ctx = require('statuesque.context')
        local status = ctx.buffer_var(context, 'vgit_status') or ctx.buffer_var(context, 'gitsigns_status_dict')
        if type(status) ~= 'table' then
            return false
        end

        local children = {}
        for _, key in ipairs({ 'added', 'changed', 'removed' }) do
            local count = tonumber(status[key]) or 0
            if count > 0 then
                children[#children + 1] = {
                    text = labels[key] .. count,
                    hl = highlights[key],
                }
                children[#children + 1] = { text = ' ' }
            end
        end

        if children[#children] ~= nil and children[#children].text == ' ' then
            children[#children] = nil
        end
        if #children == 0 then
            return opts.empty == true and { role = 'git-diff', text = opts.empty_text or '' } or false
        end

        return {
            role = 'git-diff',
            children = children,
        }
    end
end

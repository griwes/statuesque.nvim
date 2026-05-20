--- @param opts? statuesque.WidgetFiletypeOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    return function(context)
        local ctx = require('statuesque.context')
        local filetype = ctx.buffer_option(context, 'filetype')
        if filetype == '' then
            return false
        end

        local icon, icon_hl = require('statuesque.widgets.devicons').filetype_icon(filetype, opts)

        if type(icon) == 'string' and icon ~= '' then
            local icon_node = {
                role = 'filetype-icon',
                text = icon,
                hl = icon_hl,
                exact_highlight = true,
            }
            return {
                role = 'filetype',
                children = {
                    icon_node,
                    { text = opts.icon_separator or ' ' },
                    { text = filetype },
                },
            }
        end

        return {
            role = 'filetype',
            text = filetype,
        }
    end
end

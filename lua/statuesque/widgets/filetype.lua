--- @param color string
--- @return string?
local function icon_group(color)
    if type(color) ~= 'string' or not color:match('^#%x%x%x%x%x%x$') then
        return nil
    end

    color = require('statuesque.style').harmonize_color(color) or color
    local group = 'StatuesqueFileIcon' .. color:sub(2)
    vim.api.nvim_set_hl(0, group, { fg = color })
    return group
end

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

        local icon = opts.icon
        local icon_hl
        if opts.devicons ~= false then
            local ok, devicons = pcall(require, 'nvim-web-devicons')
            if ok and type(devicons.get_icon_color_by_filetype) == 'function' then
                local devicon, color = devicons.get_icon_color_by_filetype(filetype)
                icon = devicon or icon
                icon_hl = icon_group(color)
            end
        end
        if icon == true then
            icon = nil
        end

        if type(icon) == 'string' and icon ~= '' then
            local icon_node = {
                role = 'filetype-icon',
                text = icon,
                hl = icon_hl,
            }
            if opts.icon_only == true then
                return icon_node
            end
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

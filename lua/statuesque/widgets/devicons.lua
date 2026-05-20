local M = {}

--- @param color string
--- @return string?
function M.icon_group(color)
    if type(color) ~= 'string' or not color:match('^#%x%x%x%x%x%x$') then
        return nil
    end

    local group = 'StatuesqueFileIcon' .. color:sub(2)
    vim.api.nvim_set_hl(0, group, { fg = color })
    return group
end

--- @param filetype string
--- @param opts? table
--- @return string?, string?
function M.filetype_icon(filetype, opts)
    opts = opts or {}
    local icon = opts.icon
    local icon_hl
    if opts.devicons ~= false then
        local ok, devicons = pcall(require, 'nvim-web-devicons')
        if ok and type(devicons.get_icon_color_by_filetype) == 'function' then
            local devicon, color = devicons.get_icon_color_by_filetype(filetype)
            icon = devicon or icon
            icon_hl = M.icon_group(color)
        end
    end
    if icon == true then
        icon = nil
    end
    return icon, icon_hl
end

return M

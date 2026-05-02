local M = {}

--- @param value any
--- @return table
local function table_or_empty(value)
    return type(value) == 'table' and value or {}
end

--- Install the configured Statuesque window-label surface through incline.nvim.
--- @param opts? statuesque.InclineIntegrationOptions
--- @param surface? string
--- @return boolean
function M.setup(opts, surface)
    opts = table_or_empty(opts)
    if opts.enabled == false then
        return false
    end

    local ok, incline = pcall(require, 'incline')
    if not ok or type(incline.setup) ~= 'function' then
        return false
    end

    surface = surface or opts.surface or 'window_label'
    local incline_opts = vim.tbl_deep_extend('force', table_or_empty(opts.opts), {
        render = function(props)
            return require('statuesque').render_surface(surface, 'incline', {
                surface = surface,
                target = 'incline',
                winid = props.winid or props.win or props.window,
                bufnr = props.buf or props.bufnr or props.buffer,
            })
        end,
    })

    incline.setup(incline_opts)
    return true
end

return M

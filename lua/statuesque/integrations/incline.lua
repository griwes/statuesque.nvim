local M = {}
local incline_renderer = require('statuesque.render.incline')
local HIGHLIGHT_NAMESPACE = incline_renderer.highlight_namespace()

--- @param value any
--- @return table
local function table_or_empty(value)
    return type(value) == 'table' and value or {}
end

local function apply_highlight_namespace()
    incline_renderer.define_window_highlights()
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        local bufnr = vim.api.nvim_win_get_buf(winid)
        if vim.bo[bufnr].filetype == 'incline' then
            vim.api.nvim_win_set_hl_ns(winid, HIGHLIGHT_NAMESPACE)
        end
    end
end

local function install_highlight_namespace_hooks()
    local group = vim.api.nvim_create_augroup('StatuesqueInclineHighlightNamespace', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufWinEnter', 'FileType', 'WinNew', 'WinEnter' }, {
        group = group,
        callback = function()
            apply_highlight_namespace()
        end,
    })
end

--- Install the configured Statuesque incline surface through incline.nvim.
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
            local rendered = require('statuesque').render_surface(surface, 'incline', {
                surface = surface,
                target = 'incline',
                inline_highlight_namespace = HIGHLIGHT_NAMESPACE,
                winid = props.winid or props.win or props.window,
                bufnr = props.buf or props.bufnr or props.buffer,
            })
            vim.schedule(apply_highlight_namespace)
            return rendered
        end,
    })

    incline.setup(incline_opts)
    install_highlight_namespace_hooks()
    if type(incline.refresh) == 'function' then
        vim.schedule(function()
            apply_highlight_namespace()
            pcall(incline.refresh)
            apply_highlight_namespace()
        end)
    end
    return true
end

return M

local M = {}
local incline_renderer = require('statuesque.render.incline')
local HIGHLIGHT_NAMESPACE = incline_renderer.highlight_namespace()
local refresh_wrapped = false
local apply_highlight_namespace

--- @param value any
--- @return table
local function table_or_empty(value)
    return type(value) == 'table' and value or {}
end

local function schedule_highlight_namespace_apply()
    apply_highlight_namespace()
    vim.schedule(function()
        apply_highlight_namespace()
        vim.defer_fn(apply_highlight_namespace, 10)
    end)
end

function apply_highlight_namespace()
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
    vim.api.nvim_create_autocmd({
        'BufWinEnter',
        'ColorScheme',
        'FileType',
        'ModeChanged',
        'VimResized',
        'WinEnter',
        'WinNew',
        'WinScrolled',
    }, {
        group = group,
        callback = function()
            schedule_highlight_namespace_apply()
        end,
    })
end

--- @param incline table
local function wrap_refresh(incline)
    if refresh_wrapped or type(incline.refresh) ~= 'function' then
        return
    end
    local original_refresh = incline.refresh
    incline.refresh = function(...)
        local results = { original_refresh(...) }
        schedule_highlight_namespace_apply()
        return unpack(results)
    end
    refresh_wrapped = true
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

    wrap_refresh(incline)

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
            schedule_highlight_namespace_apply()
            return rendered
        end,
    })

    incline.setup(incline_opts)
    install_highlight_namespace_hooks()
    schedule_highlight_namespace_apply()
    pcall(incline.refresh)
    return true
end

return M

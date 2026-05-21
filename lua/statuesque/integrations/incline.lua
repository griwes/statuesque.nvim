local M = {}
local incline_renderer = require('statuesque.render.incline')
local HIGHLIGHT_NAMESPACE = incline_renderer.highlight_namespace()
local wrapper_states = setmetatable({}, { __mode = 'k' })
local active_incline
local active_wrapper
local apply_highlight_namespace
M._installed = false

local unpack_values = table.unpack or unpack

local function pack_values(...)
    return {
        n = select('#', ...),
        ...,
    }
end

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
    local states = wrapper_states[incline]
    if states ~= nil then
        for _, state in ipairs(states) do
            if incline.refresh == state.wrapper then
                state.enabled = true
                return state
            end
        end
    end
    if type(incline.refresh) ~= 'function' then
        return nil
    end

    local state = {
        original = incline.refresh,
        enabled = true,
    }
    state.wrapper = function(...)
        local results = pack_values(state.original(...))
        if state.enabled then
            schedule_highlight_namespace_apply()
        end
        return unpack_values(results, 1, results.n)
    end
    states = states or {}
    states[#states + 1] = state
    wrapper_states[incline] = states
    incline.refresh = state.wrapper
    return state
end

local function remove_wrapper_state(incline, state)
    local states = wrapper_states[incline]
    if states == nil then
        return
    end
    for index = #states, 1, -1 do
        if states[index] == state then
            table.remove(states, index)
            break
        end
    end
    if #states == 0 then
        wrapper_states[incline] = nil
    end
end

local function unwrap_if_exposed(incline, state)
    if incline.refresh ~= state.wrapper then
        return false
    end
    incline.refresh = state.original
    remove_wrapper_state(incline, state)
    return true
end

local function unwrap_exposed_wrappers()
    for incline, states in pairs(wrapper_states) do
        local changed = true
        while changed do
            changed = false
            for _, state in ipairs(states) do
                if unwrap_if_exposed(incline, state) then
                    changed = true
                    break
                end
            end
            states = wrapper_states[incline] or {}
        end
    end
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

    active_wrapper = wrap_refresh(incline)
    active_incline = incline

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
    if type(incline.enable) == 'function' then
        pcall(incline.enable)
    end
    install_highlight_namespace_hooks()
    schedule_highlight_namespace_apply()
    pcall(incline.refresh)
    M._installed = true
    return true
end

--- Disable an Incline instance installed by Statuesque.
function M.disable()
    local incline = active_incline
    if M._installed and incline ~= nil and type(incline.disable) == 'function' then
        pcall(incline.disable)
    end
    if active_wrapper ~= nil then
        active_wrapper.enabled = false
        unwrap_if_exposed(incline, active_wrapper)
    end
    unwrap_exposed_wrappers()
    active_incline = nil
    active_wrapper = nil
    pcall(vim.api.nvim_del_augroup_by_name, 'StatuesqueInclineHighlightNamespace')
    M._installed = false
end

return M

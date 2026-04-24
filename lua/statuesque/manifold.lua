local M = {}
local AUTO = {
    scheduled = false,
    host_attached = false,
    child_attached = false,
    attempts = 0,
}

local function plain_value(value)
    if type(value) == 'function' then
        return nil
    end

    if type(value) ~= 'table' then
        return value
    end

    local plain = {}
    for key, child in pairs(value) do
        local converted = plain_value(child)
        if converted ~= nil then
            plain[key] = converted
        end
    end
    return plain
end

--- Return Manifold child capability metadata for Statuesque.
--- @return table
function M.capabilities()
    return {
        plugin = 'statuesque',
        version = '0.1.0',
        protocol_version = 1,
        features = {
            'render_spec',
            'status_spec',
            'tabline_spec',
        },
        subscribe = true,
        snapshot = true,
    }
end

local function manifold_module()
    local ok, manifold = pcall(require, 'manifold')
    if ok and type(manifold) == 'table' then
        return manifold
    end
    return nil
end

local function is_manifold_host(manifold)
    return manifold ~= nil and type(manifold.is_host) == 'function' and manifold.is_host()
end

local function has_child_attachment()
    local control = vim.g.manifold_child_control
    return type(control) == 'table' and type(control.attachments) == 'table' and next(control.attachments) ~= nil
end

--- Export a configured Statuesque surface as plain data for a Manifold host.
--- @param surface? string
--- @param opts? table
--- @return table
function M.status_snapshot(surface, opts)
    surface = surface or 'statusline'
    local statuesque = require('statuesque')
    return {
        kind = 'statuesque.status_snapshot',
        surface = surface,
        spec = plain_value(statuesque.resolve_surface(surface, opts)),
    }
end

--- Build a status update event for a Manifold host.
--- @param surface? string
--- @param opts? table
--- @return table
function M.status_update(surface, opts)
    local snapshot = M.status_snapshot(surface, opts)
    return {
        kind = 'statuesque.status_update',
        version = 1,
        surface = snapshot.surface,
        spec = snapshot.spec,
        capabilities = M.capabilities(),
    }
end

local function publish_event(event)
    local state = vim.g.manifold_child_control
    if state == nil or state.attachments == nil then
        return 0
    end

    local published = 0
    for token, attachment in pairs(state.attachments) do
        local channel = attachment.channel
        if type(channel) ~= 'number' or channel <= 0 then
            channel = vim.fn.sockconnect('pipe', attachment.host_server, { rpc = true })
            attachment.channel = channel
            state.attachments[token] = attachment
            vim.g.manifold_child_control = state
        end

        if type(channel) == 'number' and channel > 0 then
            local ok = pcall(
                vim.fn.rpcnotify,
                channel,
                'nvim_exec_lua',
                [=[return require('manifold')._handle_child_suite_event(...) ]=],
                { token, event }
            )
            if ok then
                published = published + 1
            end
        end
    end

    return published
end

--- Publish a status update to attached Manifold hosts.
--- @param surface? string
--- @param opts? table
--- @return integer
function M.publish_status(surface, opts)
    return publish_event(M.status_update(surface, opts))
end

local function mode_name()
    local mode = vim.api.nvim_get_mode().mode
    if mode:sub(1, 1) == 'i' then
        return 'INSERT'
    end
    if mode:sub(1, 1) == 'v' or mode == 'V' or mode == '\022' then
        return 'VISUAL'
    end
    if mode:sub(1, 1) == 'R' then
        return 'REPLACE'
    end
    if mode:sub(1, 1) == 'c' then
        return 'COMMAND'
    end
    return 'NORMAL'
end

local function file_label()
    local name = vim.api.nvim_buf_get_name(0)
    if name == '' then
        return '[No Name]'
    end
    return vim.fn.fnamemodify(name, ':t')
end

local function cursor_label()
    local cursor = vim.api.nvim_win_get_cursor(0)
    return string.format('%d:%d', cursor[1], cursor[2] + 1)
end

local function child_status_spec()
    return {
        {
            role = 'child-editor-status',
            hl = 'StatusLine',
            children = {
                {
                    text = ' ' .. mode_name() .. ' ',
                    role = 'mode',
                    hl = 'ModeMsg',
                },
                {
                    text = ' ' .. file_label() .. ' ',
                    role = 'file',
                    hl = 'StatusLine',
                    max_width = 32,
                    truncate = 'left',
                },
                {
                    text = ' ' .. cursor_label() .. ' ',
                    role = 'position',
                    hl = 'StatusLine',
                },
            },
        },
    }
end

local function schedule_publish(surface)
    if M._pending_status_publish then
        return
    end
    M._pending_status_publish = true
    vim.schedule(function()
        M._pending_status_publish = false
        M.publish_status(surface or 'statusline')
    end)
end

--- Enable host-side Statuesque provider behavior inside a Manifold host.
--- @param opts? { surface?: string, install?: boolean }
--- @return boolean
function M.setup_host(opts)
    opts = opts or {}
    local manifold = manifold_module()
    if not is_manifold_host(manifold) or type(manifold.install_statusline_provider) ~= 'function' then
        return false
    end

    return manifold.install_statusline_provider({
        surface = opts.surface or 'statusline',
        install = opts.install ~= false,
    })
end

--- Enable child-side editor status export to an attached Manifold host.
--- @param opts? { surface?: string, suppress_local?: boolean }
function M.setup_child(opts)
    opts = opts or {}
    local surface = opts.surface or 'statusline'
    local statuesque = require('statuesque')
    statuesque.register_provider('statuesque.child-editor-status', child_status_spec)
    statuesque.set_surface(surface, 'statuesque.child-editor-status')

    if opts.suppress_local ~= false then
        vim.o.laststatus = 0
        vim.o.statusline = ''
    end

    local group = vim.api.nvim_create_augroup('StatuesqueExternalChildStatus', { clear = true })
    vim.api.nvim_create_autocmd({
        'BufEnter',
        'BufFilePost',
        'CursorMoved',
        'CursorMovedI',
        'ModeChanged',
        'WinEnter',
    }, {
        group = group,
        callback = function()
            schedule_publish(surface)
        end,
    })
    schedule_publish(surface)
end

--- Detect Manifold host/child context and enable the matching integration.
--- @param opts? { host?: table|false, child?: table|false, max_attempts?: integer }
function M.auto_setup(opts)
    opts = opts or {}
    if opts.host ~= false and not AUTO.host_attached and M.setup_host(opts.host or {}) then
        AUTO.host_attached = true
    end

    if opts.child ~= false and not AUTO.child_attached and has_child_attachment() then
        M.setup_child(opts.child or {})
        AUTO.child_attached = true
    end

    if AUTO.host_attached or AUTO.child_attached then
        return
    end
    local max_attempts = opts.max_attempts or 80
    if AUTO.scheduled or AUTO.attempts >= max_attempts then
        return
    end

    AUTO.scheduled = true
    AUTO.attempts = AUTO.attempts + 1
    vim.defer_fn(function()
        AUTO.scheduled = false
        M.auto_setup(opts)
    end, 50)
end

return M

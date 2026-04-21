local M = {}

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

return M

local cache = require('statuesque.cache')

local M = {
    _subscriptions = setmetatable({}, {
        __mode = 'k',
    }),
}

local function schedule_redraw()
    if vim == nil or vim.schedule == nil then
        return
    end

    vim.schedule(function()
        pcall(vim.cmd, 'redrawstatus')
    end)
end

function M.is_component(value)
    if type(value) ~= 'table' then
        return false
    end

    return value.statuesque_component == true
        or type(value.statuesque_render) == 'function'
        or type(value.capabilities) == 'table'
end

function M.render(component, context)
    if type(component.statuesque_render) == 'function' then
        return component:statuesque_render(context)
    end

    if type(component.render) == 'function' then
        return component:render(context)
    end

    return component.value
end

function M.ensure_subscription(component, key, opts)
    local subscribe = component.statuesque_subscribe or component.subscribe
    if type(subscribe) ~= 'function' or M._subscriptions[component] ~= nil then
        return
    end

    local function notify()
        cache.invalidate(key)
        if opts and type(opts.on_update) == 'function' then
            opts.on_update(component)
            return
        end
        schedule_redraw()
    end

    M._subscriptions[component] = subscribe(component, notify) or true
end

function M.new(render, subscribe, opts)
    opts = opts or {}
    return {
        statuesque_component = true,
        cache = opts.cache,
        render = render,
        subscribe = subscribe,
    }
end

return M

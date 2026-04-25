local cache = require('statuesque.cache')

local M = {
    _subscriptions = setmetatable({}, {
        __mode = 'k',
    }),
}

--- @return nil
local function schedule_redraw()
    if vim == nil or vim.schedule == nil then
        return
    end

    vim.schedule(function()
        pcall(vim.cmd, 'redrawstatus')
    end)
end

--- @param value any
--- @return boolean
function M.is_component(value)
    if type(value) ~= 'table' then
        return false
    end

    return value.statuesque_component == true
        or type(value.statuesque_render) == 'function'
        or type(value.capabilities) == 'table'
end

--- @param component statuesque.PublisherComponent
--- @param context? statuesque.RenderContext
--- @return statuesque.RenderSpec
function M.render(component, context)
    if type(component.statuesque_render) == 'function' then
        return component:statuesque_render(context)
    end

    if type(component.render) == 'function' then
        return component:render(context)
    end

    return component.value
end

--- @param component statuesque.PublisherComponent
--- @param key any
--- @param opts? statuesque.RenderContext
--- @return nil
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

--- Create a self-publishing component.
--- @param render fun(self: statuesque.PublisherComponent, context?: statuesque.RenderContext): statuesque.RenderSpec
--- @param subscribe? fun(self: statuesque.PublisherComponent, notify: fun()): any
--- @param opts? { cache?: statuesque.CacheConfig }
--- @return statuesque.PublisherComponent
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

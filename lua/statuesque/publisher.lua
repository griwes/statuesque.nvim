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
    if type(subscribe) ~= 'function' then
        return
    end

    local record = M._subscriptions[component]
    if record == nil then
        record = {
            keys = {},
            callbacks = {},
            redraw = false,
        }
        M._subscriptions[component] = record

        local record_ref = setmetatable({ record }, { __mode = 'v' })
        local component_ref = setmetatable({ component }, { __mode = 'v' })

        local function notify()
            local live_record = record_ref[1]
            local live_component = component_ref[1]
            if live_record == nil or live_component == nil then
                return
            end
            for cache_key in pairs(live_record.keys) do
                cache.invalidate(cache_key)
            end
            for callback in pairs(live_record.callbacks) do
                callback(live_component)
            end
            if live_record.redraw then
                schedule_redraw()
            end
        end

        record.subscription = subscribe(component, notify) or true
    end

    if key ~= nil then
        record.keys[key] = true
    end
    if opts and type(opts.on_update) == 'function' then
        record.callbacks[opts.on_update] = true
    else
        record.redraw = true
    end
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

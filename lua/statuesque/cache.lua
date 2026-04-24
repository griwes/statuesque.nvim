local M = {
    _values = {},
    _rendered = {},
}

local function cache_enabled(cache_opts)
    if cache_opts == nil then
        return false
    end
    if cache_opts == true then
        return true
    end
    if type(cache_opts) == 'table' and cache_opts.enabled == false then
        return false
    end
    return type(cache_opts) == 'table'
end

function M.key_for(component, fallback)
    local cache_opts = type(component) == 'table' and component.cache or nil
    if not cache_enabled(cache_opts) then
        return nil
    end

    if type(cache_opts) == 'table' and cache_opts.key ~= nil then
        return cache_opts.key
    end

    if type(component) == 'table' and component.id ~= nil then
        return component.id
    end

    if cache_opts == true then
        return component
    end

    return fallback or component
end

function M.get(key, compute)
    if key == nil then
        return compute()
    end

    local record = M._values[key]
    if record ~= nil then
        return record
    end

    record = compute()
    M._values[key] = record
    return record
end

function M.get_rendered(target, key, variant, compute)
    if key == nil then
        return compute()
    end

    local by_target = M._rendered[key]
    if by_target == nil then
        by_target = {}
        M._rendered[key] = by_target
    end

    local renderer_key = ('%s:%s'):format(target, variant or 'default')
    if by_target[renderer_key] ~= nil then
        return by_target[renderer_key]
    end

    local rendered = compute()
    by_target[renderer_key] = rendered
    return rendered
end

function M.invalidate(key)
    if key == nil then
        M._values = {}
        M._rendered = {}
        return
    end

    M._values[key] = nil
    M._rendered[key] = nil
end

return M

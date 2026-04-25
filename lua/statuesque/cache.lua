local M = {
    _values = {},
    _rendered = {},
}

local context = require('statuesque.context')

--- @param cache_opts? statuesque.CacheConfig
--- @return boolean
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

--- Return the cache key for a component, if that component requests caching.
--- @param component any
--- @param fallback? any
--- @param opts? statuesque.RenderContext
--- @return any?
function M.key_for(component, fallback, opts)
    local cache_opts = type(component) == 'table' and component.cache or nil
    if not cache_enabled(cache_opts) then
        return nil
    end

    if type(cache_opts) == 'table' and cache_opts.key ~= nil then
        return M.scoped_key(cache_opts.key, opts, cache_opts)
    end

    if type(component) == 'table' and component.id ~= nil then
        return M.scoped_key(component.id, opts, cache_opts)
    end

    if cache_opts == true then
        return M.scoped_key(component, opts, cache_opts)
    end

    return M.scoped_key(fallback or component, opts, cache_opts)
end

--- @param key any
--- @param opts? statuesque.RenderContext
--- @param cache_opts? statuesque.CacheConfig
--- @return any
function M.scoped_key(key, opts, cache_opts)
    local variant = context.cache_variant(opts, cache_opts)
    if variant == nil then
        return key
    end

    local encoded_key = tostring(key)
    return ('statuesque-scoped:%d:%s:%s'):format(#encoded_key, encoded_key, variant)
end

--- Return a cached value for `key`, computing it on first use.
--- @generic T
--- @param key any?
--- @param compute fun(): T
--- @return T
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

--- Return a cached renderer-specific value for `key` and `variant`.
--- @generic T
--- @param target statuesque.Target
--- @param key any?
--- @param variant? string
--- @param compute fun(): T
--- @return T
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

--- Invalidate all cache entries, or entries for a specific key.
--- @param key? any
function M.invalidate(key)
    if key == nil then
        M._values = {}
        M._rendered = {}
        return
    end

    M._values[key] = nil
    M._rendered[key] = nil

    local encoded_key = tostring(key)
    local scoped_prefix = ('statuesque-scoped:%d:%s:'):format(#encoded_key, encoded_key)
    for cached_key in pairs(M._values) do
        if type(cached_key) == 'string' and cached_key:sub(1, #scoped_prefix) == scoped_prefix then
            M._values[cached_key] = nil
        end
    end
    for cached_key in pairs(M._rendered) do
        if type(cached_key) == 'string' and cached_key:sub(1, #scoped_prefix) == scoped_prefix then
            M._rendered[cached_key] = nil
        end
    end
end

return M

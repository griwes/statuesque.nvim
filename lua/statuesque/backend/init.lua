local M = {
    _registered = {},
}

local BUILTIN_CAPABILITIES = {
    debug = {
        render_scope = 'global',
        snapshot = true,
        highlights = 'preserved',
        clicks = 'preserved',
        hover = 'preserved',
        align = 'preserved',
        raw = 'preserved',
        install = false,
    },
    text = {
        render_scope = 'global',
        snapshot = false,
        highlights = false,
        clicks = false,
        hover = false,
        align = false,
        raw = true,
        install = false,
    },
    vim = {
        render_scope = 'global',
        snapshot = false,
        highlights = true,
        clicks = true,
        hover = 'registered',
        hover_degradation = 'requires_surface_hit_testing',
        align = true,
        raw = true,
        install = false,
    },
    statusline = {
        render_scope = 'global',
        snapshot = false,
        highlights = true,
        clicks = true,
        hover = 'registered',
        hover_degradation = 'requires_surface_hit_testing',
        align = true,
        raw = true,
        install = true,
        global_statusline = true,
    },
    tabline = {
        render_scope = 'global',
        snapshot = false,
        highlights = true,
        clicks = true,
        hover = 'registered',
        hover_degradation = 'requires_surface_hit_testing',
        align = true,
        raw = true,
        install = true,
    },
    winbar = {
        render_scope = 'window',
        window_context = true,
        buffer_context = true,
        snapshot = false,
        highlights = true,
        clicks = true,
        hover = 'registered',
        hover_degradation = 'requires_surface_hit_testing',
        align = true,
        raw = true,
        install = true,
    },
    incline = {
        render_scope = 'window',
        window_context = true,
        buffer_context = true,
        snapshot = false,
        highlights = 'groups',
        clicks = false,
        click_degradation = 'metadata',
        hover = false,
        hover_degradation = 'metadata',
        align = false,
        raw = true,
        install = false,
        degradation_metadata = true,
    },
}

local BUILTIN = {
    debug = 'statuesque.render.debug',
    text = 'statuesque.render.text',
    vim = 'statuesque.render.vim',
    statusline = 'statuesque.render.statusline',
    tabline = 'statuesque.render.tabline',
    winbar = 'statuesque.render.winbar',
    incline = 'statuesque.render.incline',
}

--- @generic T
--- @param value T
--- @return T
local function copy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copied = {}
    for key, child in pairs(value) do
        copied[key] = copy(child)
    end
    return copied
end

--- @param name statuesque.Target
--- @param backend statuesque.Backend
--- @return statuesque.BackendCapabilities
local function capabilities_for(name, backend)
    local capabilities = copy(BUILTIN_CAPABILITIES[name] or {})
    if type(backend.capabilities) == 'table' then
        capabilities = vim.tbl_deep_extend('force', capabilities, backend.capabilities)
    end
    capabilities.target = name
    return capabilities
end

--- @param value any
--- @return boolean
local function is_backend(value)
    return type(value) == 'table' and type(value.render) == 'function'
end

--- @param name string
--- @return string
local function backend_contract_error(name)
    return ('invalid statuesque backend %q: expected table with render(spec, opts)'):format(name)
end

--- Register a render backend.
--- @param name string
--- @param backend statuesque.Backend
function M.register(name, backend)
    assert(type(name) == 'string' and name ~= '', 'backend name must be a non-empty string')
    assert(is_backend(backend), 'backend must expose render(spec, opts)')
    M._registered[name] = backend
end

--- Resolve a render backend by name.
--- @param name statuesque.Target
--- @return statuesque.Backend?
function M.resolve(name)
    if M._registered[name] ~= nil then
        return M._registered[name]
    end

    local module_name = BUILTIN[name] or ('statuesque.backend.' .. name)
    local ok, backend = pcall(require, module_name)
    if not ok then
        if type(backend) == 'string' and backend:find(("module '%s' not found"):format(module_name), 1, true) then
            return nil
        end
        error(backend)
    end

    if not is_backend(backend) then
        error(backend_contract_error(name))
    end

    M._registered[name] = backend
    return backend
end

--- Render a spec through a named backend.
--- @param name statuesque.Target
--- @param render_spec statuesque.RenderSpec
--- @param opts? statuesque.RenderContext
--- @return any
function M.render(name, render_spec, opts)
    local backend = M.resolve(name)
    if backend == nil then
        error(('unsupported statuesque render target: %s'):format(name))
    end

    return backend.render(render_spec, opts)
end

--- Return capability metadata for a backend, if available.
--- @param name statuesque.Target
--- @return statuesque.BackendCapabilities?
function M.capabilities(name)
    local backend = M.resolve(name)
    if backend == nil then
        return nil
    end

    return capabilities_for(name, backend)
end

return M

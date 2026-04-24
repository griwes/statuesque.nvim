local M = {
    _providers = {},
    _surfaces = {},
    _pending_manifold_status = {},
}

local function maybe_publish_manifold_status(surface_or_provider)
    local surface = surface_or_provider == 'statusline' and 'statusline' or nil
    if surface == nil and M._surfaces.statusline == surface_or_provider then
        surface = 'statusline'
    end
    if surface == nil then
        return
    end
    if M._pending_manifold_status[surface] then
        return
    end

    M._pending_manifold_status[surface] = true
    vim.schedule(function()
        M._pending_manifold_status[surface] = nil
        pcall(function()
            require('statuesque.manifold').publish_status(surface)
        end)
    end)
end

function M.setup(config)
    config = config or {}
    require('statuesque.config').configure(config)
    require('statuesque.style').define_default_highlights()

    if config.preset ~= nil and config.preset ~= false then
        local preset_opts = type(config.preset) == 'table' and config.preset or {}
        require('statuesque.presets.default').install(preset_opts)
    end

    if config.manifold ~= false then
        local manifold_opts = type(config.manifold) == 'table' and config.manifold or {}
        require('statuesque.manifold').auto_setup(manifold_opts)
    end
end

--- Normalize a recursive render specification into Statuesque's canonical node list.
--- @param render_spec any
--- @param opts? table
--- @return table[]
function M.normalize(render_spec, opts)
    return require('statuesque.spec').normalize(render_spec, opts)
end

--- Render a recursive render specification for a target.
--- @param render_spec any
--- @param target? 'debug'|'text'|'vim'|'statusline'|'tabline'|'winbar'|'incline'
--- @param opts? table
--- @return any
function M.render(render_spec, target, opts)
    target = target or 'text'
    return require('statuesque.backend').render(target, render_spec, opts)
end

function M.register_backend(name, backend)
    require('statuesque.backend').register(name, backend)
end

function M.invalidate(key)
    require('statuesque.cache').invalidate(key)
end

function M.compose(components, opts)
    return require('statuesque.style').compose(components, opts)
end

--- Register a named render provider.
--- @param name string
--- @param provider fun(context?: table):any|any
function M.register_provider(name, provider)
    assert(type(name) == 'string' and name ~= '', 'provider name must be a non-empty string')
    assert(provider ~= nil, 'provider must not be nil')
    M._providers[name] = provider
    maybe_publish_manifold_status(name)
end

--- Bind a render provider or literal render spec to a display surface.
--- @param surface string
--- @param provider_or_spec string|fun(context?: table):any|any
function M.set_surface(surface, provider_or_spec)
    assert(type(surface) == 'string' and surface ~= '', 'surface must be a non-empty string')
    M._surfaces[surface] = provider_or_spec
    maybe_publish_manifold_status(surface)
end

--- Resolve a configured surface to the producer's raw render spec.
--- @param surface string
--- @param opts? table
--- @return any
function M.resolve_surface(surface, opts)
    local provider_or_spec = M._surfaces[surface]
    if type(provider_or_spec) == 'string' then
        provider_or_spec = M._providers[provider_or_spec]
    end

    if type(provider_or_spec) == 'function' then
        return provider_or_spec(opts or {})
    end

    return provider_or_spec or {}
end

--- Render a configured surface.
--- @param surface string
--- @param target? string
--- @param opts? table
--- @return any
function M.render_surface(surface, target, opts)
    return M.render(M.resolve_surface(surface, opts), target, opts)
end

--- Publish a configured surface to any detected external consumers.
--- @param surface? string
--- @param opts? table
--- @return integer
function M.publish(surface, opts)
    return require('statuesque.manifold').publish_status(surface or 'statusline', opts)
end

--- Produce a Vim expression suitable for a statusline-family option.
--- @param surface string
--- @param target 'statusline'|'tabline'|'winbar'
--- @return string
function M.surface_expression(surface, target)
    assert(type(surface) == 'string' and surface ~= '', 'surface must be a non-empty string')
    assert(type(target) == 'string' and target ~= '', 'target must be a non-empty string')
    return ("%%!v:lua.require'statuesque'.render_surface(%q, %q)"):format(surface, target)
end

--- Install a configured surface into a Vim statusline-family option.
--- @param surface string
--- @param target 'statusline'|'tabline'|'winbar'
function M.install_surface(surface, target)
    local expression = M.surface_expression(surface, target)

    if target == 'statusline' then
        vim.o.laststatus = 3
        vim.o.statusline = expression
        return
    end

    if target == 'tabline' then
        vim.o.showtabline = 2
        vim.o.tabline = expression
        return
    end

    if target == 'winbar' then
        vim.o.winbar = expression
        return
    end

    error(('unsupported install target: %s'):format(target))
end

--- Dispatch a click registered while rendering a Vim statusline-family target.
--- @param id integer|string
--- @param button? string
--- @param modifiers? string
--- @param context? table
--- @return any
function M.click(id, button, modifiers, context)
    return require('statuesque.clicks').dispatch(id, button, modifiers, context)
end

return M

local M = {
    _providers = {},
    _surfaces = {},
    _pending_manifold_status = {},
}

--- @return statuesque.PublishConfig
local function publish_config()
    return require('statuesque.config').config.publish or {}
end

--- @param surface string
--- @return boolean
function M.should_auto_publish(surface)
    local auto = publish_config().auto
    if auto == true then
        return true
    end
    if type(auto) ~= 'table' then
        return false
    end
    return auto[surface] == true
end

--- @param provider_name string
--- @return string[]
local function surfaces_for_provider(provider_name)
    local surfaces = {}
    for surface, provider_or_spec in pairs(M._surfaces) do
        if provider_or_spec == provider_name then
            surfaces[#surfaces + 1] = surface
        end
    end
    return surfaces
end

--- @param surface string
local function schedule_manifold_publish(surface)
    if not M.should_auto_publish(surface) then
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

--- @param surface_or_provider string
local function maybe_publish_manifold_status(surface_or_provider)
    if M._surfaces[surface_or_provider] ~= nil then
        schedule_manifold_publish(surface_or_provider)
        return
    end

    for _, surface in ipairs(surfaces_for_provider(surface_or_provider)) do
        schedule_manifold_publish(surface)
    end
end

--- @param value any
--- @return statuesque.ManifoldAutoOptions
local function manifold_options(value)
    if type(value) == 'table' then
        return value
    end
    return {}
end

--- Configure Statuesque and optional preset / Manifold integrations.
--- @param config? statuesque.SetupConfig
function M.setup(config)
    config = config or {}
    require('statuesque.config').configure(config)
    require('statuesque.style').define_default_highlights()

    if config.surfaces ~= nil or (config.preset ~= nil and config.preset ~= false) then
        require('statuesque.presets.default').install(config)
    end

    if config.manifold ~= false then
        require('statuesque.manifold').auto_setup(manifold_options(config.manifold))
    end
end

--- Return the active Statuesque visual style name.
--- @return string
function M.style_name()
    return require('statuesque.config').style()
end

--- Subscribe to Statuesque visual style changes.
--- @param callback fun(style: string)
--- @return fun()
function M.on_style_change(callback)
    return require('statuesque.config').on_style_change(callback)
end

--- Normalize a recursive render specification into Statuesque's canonical node list.
--- @param render_spec statuesque.RenderSpec
--- @param opts? statuesque.RenderContext
--- @return statuesque.NormalizedNode[]
function M.normalize(render_spec, opts)
    return require('statuesque.spec').normalize(render_spec, opts)
end

--- Render a recursive render specification for a target.
--- @param render_spec statuesque.RenderSpec
--- @param target? statuesque.Target
--- @param opts? statuesque.RenderContext
--- @return any
function M.render(render_spec, target, opts)
    target = target or 'text'
    return require('statuesque.backend').render(target, render_spec, opts)
end

--- Return render backend capability metadata.
--- @param name statuesque.Target
--- @return statuesque.BackendCapabilities
function M.backend_capabilities(name)
    local capabilities = require('statuesque.backend').capabilities(name)
    if capabilities == nil then
        error(('unsupported statuesque render target: %s'):format(name))
    end
    return capabilities
end

--- Invalidate all caches, or the cache entry associated with `key`.
--- @param key? any
function M.invalidate(key)
    require('statuesque.cache').invalidate(key)
end

--- Compose a styled bar render spec from left/right or linear components.
--- @param components statuesque.ComposeInput
--- @param opts? statuesque.ComposeOptions
--- @return statuesque.RenderNode
function M.compose(components, opts)
    return require('statuesque.style').compose(components, opts)
end

--- Register a named render provider.
--- @param name string
--- @param provider statuesque.Provider
function M.register_provider(name, provider)
    assert(type(name) == 'string' and name ~= '', 'provider name must be a non-empty string')
    assert(provider ~= nil, 'provider must not be nil')
    M._providers[name] = provider
    maybe_publish_manifold_status(name)
end

--- Bind a render provider or literal render spec to a display surface.
--- @param surface string
--- @param provider_or_spec string|statuesque.Provider
function M.set_surface(surface, provider_or_spec)
    assert(type(surface) == 'string' and surface ~= '', 'surface must be a non-empty string')
    M._surfaces[surface] = provider_or_spec
    maybe_publish_manifold_status(surface)
end

--- Resolve a configured surface to the producer's raw render spec.
--- @param surface string
--- @param opts? statuesque.RenderContext
--- @return statuesque.RenderSpec
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
--- @param target? statuesque.Target
--- @param opts? statuesque.RenderContext
--- @return any
function M.render_surface(surface, target, opts)
    local context = require('statuesque.context').with_target(opts, target or 'text')
    return M.render(M.resolve_surface(surface, context), target, context)
end

--- Render an installed statusline-family surface with backend-owned context.
--- Statusline and tabline stay global; winbar gets Neovim's evaluated window.
--- @param surface string
--- @param target 'statusline'|'tabline'|'winbar'
--- @return any
function M.render_installed_surface(surface, target)
    local context = require('statuesque.context').with_target({
        surface = surface,
    }, target)
    return M.render_surface(surface, target, context)
end

--- Publish a configured surface to any detected external consumers.
--- @param surface? string
--- @param opts? statuesque.RenderContext
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
    return ("%%!v:lua.require'statuesque'.render_installed_surface(%q, %q)"):format(surface, target)
end

--- Install a configured surface into a Vim statusline-family option.
--- @param surface string
--- @param target 'statusline'|'tabline'|'winbar'
--- @return nil
function M.install_surface(surface, target)
    local expression = M.surface_expression(surface, target)
    require('statuesque.hovers').install_surface(surface, target)

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

--- Dispatch a hover registered while rendering a target that preserves hover metadata.
--- @param id integer|string
--- @param phase? statuesque.HoverPhase
--- @param context? table
--- @return any
function M.hover(id, phase, context)
    return require('statuesque.hovers').dispatch(id, phase, context)
end

return M

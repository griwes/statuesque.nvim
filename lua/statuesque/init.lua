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
    require('statuesque.config').configure(config)
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

    if target == 'debug' then
        return require('statuesque.render.debug').render(render_spec, opts)
    end

    if target == 'text' then
        return require('statuesque.render.text').render(render_spec, opts)
    end

    if target == 'incline' then
        return require('statuesque.render.incline').render(render_spec, opts)
    end

    if target == 'statusline' then
        return require('statuesque.render.statusline').render(render_spec, opts)
    end

    if target == 'tabline' then
        return require('statuesque.render.tabline').render(render_spec, opts)
    end

    if target == 'winbar' then
        return require('statuesque.render.winbar').render(render_spec, opts)
    end

    if target == 'vim' then
        return require('statuesque.render.vim').render(render_spec, opts)
    end

    error(('unsupported statuesque render target: %s'):format(target))
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
--- @param opts? { globalstatus?: boolean }
function M.install_surface(surface, target, opts)
    opts = opts or {}
    local expression = M.surface_expression(surface, target)

    if target == 'statusline' then
        if opts.globalstatus ~= false then
            vim.o.laststatus = 3
        end
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

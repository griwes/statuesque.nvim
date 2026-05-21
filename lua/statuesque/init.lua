local M = {
    _providers = {},
    _surfaces = {},
    _pending_manifold_status = {},
    _installed_options = {},
    _preset_surfaces = {},
    _visual_hooks_installed = false,
    _surface_config = nil,
    _surface_plan = nil,
}

local TARGET_OPTIONS = {
    statusline = { option = 'statusline', companion = 'laststatus', companion_value = 3 },
    tabline = { option = 'tabline', companion = 'showtabline', companion_value = 2 },
    winbar = { option = 'winbar' },
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

local function refresh_visual_state()
    require('statuesque.cache').invalidate()
    require('statuesque.style').define_default_highlights()
    pcall(vim.cmd, 'redrawstatus')
    pcall(vim.cmd, 'redrawtabline')
    local ok, incline = pcall(require, 'incline')
    if ok and type(incline.refresh) == 'function' then
        pcall(incline.refresh)
    end
end

local function install_visual_hooks()
    if M._visual_hooks_installed then
        return
    end
    M._visual_hooks_installed = true
    local group = vim.api.nvim_create_augroup('StatuesqueVisualState', { clear = true })
    vim.api.nvim_create_autocmd('ColorScheme', {
        group = group,
        callback = refresh_visual_state,
    })
end

local function uninstall_surfaces()
    for target, record in pairs(M._installed_options) do
        local descriptor = TARGET_OPTIONS[target]
        if descriptor ~= nil then
            if vim.o[descriptor.option] == record.expression then
                vim.o[descriptor.option] = record.option
            end
            if descriptor.companion ~= nil and vim.o[descriptor.companion] == record.companion_value then
                vim.o[descriptor.companion] = record.companion
            end
        end
        require('statuesque.clicks').uninstall_target(target)
        require('statuesque.hovers').uninstall_surface(target)
    end
    M._installed_options = {}
    require('statuesque.integrations.incline').disable()
end

local function copy_map(value, deep)
    local copied = {}
    for key, item in pairs(value) do
        if deep and type(item) == 'table' then
            copied[key] = vim.deepcopy(item)
        else
            copied[key] = item
        end
    end
    return copied
end

local function capture_installed_option_values()
    local values = {}
    for target in pairs(M._installed_options) do
        local descriptor = TARGET_OPTIONS[target]
        if descriptor ~= nil then
            values[target] = {
                option = vim.o[descriptor.option],
                companion = descriptor.companion and vim.o[descriptor.companion] or nil,
            }
        end
    end
    return values
end

local function restore_surface_state(state)
    uninstall_surfaces()
    require('statuesque.config').configure(state.config)
    require('statuesque.style').define_default_highlights()
    M._surfaces = state.surfaces
    M._preset_surfaces = state.preset_surfaces
    M._surface_config = state.surface_config
    M._surface_plan = state.surface_plan

    if state.surface_plan ~= nil then
        require('statuesque.presets.default').install(state.surface_config, state.surface_plan)
    end
    for target, record in pairs(state.installed_options) do
        if M._installed_options[target] == nil and record.surface ~= nil then
            M.install_surface(record.surface, target)
        end
    end
    for target, values in pairs(state.option_values) do
        local descriptor = TARGET_OPTIONS[target]
        vim.o[descriptor.option] = values.option
        if descriptor.companion ~= nil then
            vim.o[descriptor.companion] = values.companion
        end
    end
end

--- Configure Statuesque and optional preset / Manifold integrations.
--- @param config? statuesque.SetupConfig
function M.setup(config)
    config = config or {}
    local reconfigure_surfaces = config.surfaces ~= nil or config.preset ~= nil
    if reconfigure_surfaces then
        local default_preset = require('statuesque.presets.default')
        local prepared = default_preset.prepare(config)
        local previous_state = {
            config = vim.deepcopy(require('statuesque.config').config),
            surfaces = copy_map(M._surfaces),
            preset_surfaces = copy_map(M._preset_surfaces),
            installed_options = copy_map(M._installed_options, true),
            option_values = capture_installed_option_values(),
            surface_config = M._surface_config,
            surface_plan = M._surface_plan,
        }
        local ok, err = xpcall(function()
            uninstall_surfaces()
            for surface in pairs(M._preset_surfaces) do
                M._surfaces[surface] = nil
            end
            M._preset_surfaces = {}
            require('statuesque.config').configure(config)
            require('statuesque.style').define_default_highlights()
            install_visual_hooks()

            local surfaces = default_preset.install(config, prepared)
            for surface in pairs(surfaces) do
                M._preset_surfaces[surface] = true
            end
            M._surface_config = config
            M._surface_plan = prepared
        end, debug.traceback)
        if not ok then
            local rollback_ok, rollback_err = pcall(restore_surface_state, previous_state)
            if not rollback_ok then
                error(('%s\nStatuesque setup rollback failed: %s'):format(err, rollback_err), 0)
            end
            error(err, 0)
        end
    else
        require('statuesque.config').configure(config)
        require('statuesque.style').define_default_highlights()
        install_visual_hooks()
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
    local context = require('statuesque.context').with_target(
        vim.tbl_extend('force', opts or {}, {
            surface = surface,
        }),
        target or 'text'
    )
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
        _statuesque_installed_render = true,
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
    local descriptor = TARGET_OPTIONS[target]
    if descriptor == nil then
        error(('unsupported install target: %s'):format(target))
    end
    local expression = M.surface_expression(surface, target)
    if M._installed_options[target] == nil then
        M._installed_options[target] = {
            option = vim.o[descriptor.option],
            companion = descriptor.companion and vim.o[descriptor.companion] or nil,
            companion_value = descriptor.companion_value,
            expression = expression,
            surface = surface,
        }
    else
        M._installed_options[target].expression = expression
        M._installed_options[target].surface = surface
    end
    require('statuesque.hovers').install_surface(surface, target)

    if descriptor.companion ~= nil then
        vim.o[descriptor.companion] = descriptor.companion_value
    end
    vim.o[descriptor.option] = expression
end

---Replace a window-local render target while a window displays a given buffer.
---The replacement is automatically cleared when that window shows another buffer.
---@param opts statuesque.WindowSurfaceReplacement
---@return integer[]
function M.replace_window_surface(opts)
    return require('statuesque.window_surface').replace(opts)
end

---Clear a window-local render target replacement installed through Statuesque.
---@param winid integer
---@param target string
function M.clear_window_surface(winid, target)
    require('statuesque.window_surface').clear(winid, target)
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

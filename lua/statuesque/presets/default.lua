local style = require('statuesque.style')
local M = {}

--- @return boolean
local function has_tabulature()
    local ok = pcall(require, 'tabulature')
    return ok
end

--- @param config statuesque.Config
--- @return table
local function preset_opts(config)
    if type(config.preset) == 'table' and type(config.preset.opts) == 'table' then
        return config.preset.opts
    end
    return {}
end

--- @param config statuesque.Config
--- @return string|boolean|nil
local function preset_name(config)
    if type(config.preset) == 'table' then
        if config.preset[1] == nil then
            error('Statuesque preset tables must name the preset as the first array item')
        end
        return config.preset[1]
    end
    return config.preset
end

--- @param global_config statuesque.Config
--- @param surface_config statuesque.SurfaceConfig
--- @param surface statuesque.Surface
--- @param sigil? string|false
--- @return statuesque.ComposeOptions
local function compose_opts(global_config, surface_config, surface, sigil)
    return {
        surface = surface,
        sigil = sigil,
        placement = surface_config.placement,
        base = surface_config.base or global_config.base,
        segment_layout = surface_config.segment_layout or global_config.segment_layout,
        gap_padding = surface_config.gap_padding or global_config.gap_padding,
        layout = surface_config.layout or global_config.layout,
        style = surface_config.style or global_config.style,
    }
end

--- @param config statuesque.Config
--- @return statuesque.SurfacePlacement
local function window_label_placement(config)
    local window_label = type(config.window_label) == 'table' and config.window_label or {}
    local preset = preset_opts(config)
    local preset_window_label = type(preset.window_label) == 'table' and preset.window_label or {}
    local targets = type(config.targets) == 'table' and config.targets or {}
    local target = type(targets.window_label) == 'table' and targets.window_label or {}

    local vertical = nil
    if type(window_label.placement) == 'table' then
        vertical = window_label.placement.vertical
    end
    vertical = vertical or window_label.vertical
    if type(preset_window_label.placement) == 'table' then
        vertical = vertical or preset_window_label.placement.vertical
    end
    vertical = vertical or preset_window_label.vertical
    if type(target.placement) == 'table' then
        vertical = vertical or target.placement.vertical
    end

    return {
        vertical = vertical or 'bottom',
    }
end

--- @param config statuesque.Config
--- @return false|statuesque.HighlightSpec
local function window_label_background(config)
    local window_label = type(config.window_label) == 'table' and config.window_label or {}
    local preset = preset_opts(config)
    local preset_window_label = type(preset.window_label) == 'table' and preset.window_label or {}

    local background = window_label.background
    if background == nil then
        background = preset_window_label.background
    end
    if background == nil or background == false or background == 'transparent' or background == 'none' then
        return false
    end
    if type(background) == 'table' then
        return background
    end
    if type(background) == 'string' then
        return {
            bg = background,
        }
    end
    error('window_label.background must be false, "transparent", "none", a color string, or a highlight table')
end

--- @param config statuesque.Config
--- @param surface_config statuesque.SurfaceConfig
local function apply_window_label_config(config, surface_config)
    if surface_config.placement == nil then
        surface_config.placement = window_label_placement(config)
    end
    if surface_config.base == nil then
        local background = window_label_background(config)
        if background ~= false then
            surface_config.base = background
        end
    end
end

--- @param surface string
--- @param backend statuesque.SurfaceBackendConfig
--- @return boolean
local function is_single_sided_backend(surface, backend)
    local capabilities = require('statuesque.backend').capabilities(backend.name or surface)
    return type(capabilities) == 'table' and capabilities.align == false
end

--- @param config statuesque.Config
--- @return table<string, statuesque.SurfaceConfig|false>
local function default_surface_configs(config)
    local opts = preset_opts(config)
    local tabulature_enabled = opts.tabulature == true or (opts.tabulature == nil and has_tabulature())
    local tabline_sigil = tabulature_enabled and style.backend_defaults('tabline').tabulature_sigil or nil

    local surfaces = {
        statusline = {
            left = {
                { name = 'mode', opts = opts.mode or {} },
                { name = 'diagnostics', opts = { empty = false } },
                { name = 'quickfix', opts = opts.quickfix or {} },
                { name = 'dap', opts = opts.dap or {} },
                { name = 'git_repo', optional = true, opts = opts.git_repo or {} },
            },
            right = {
                { name = 'filetype' },
                { name = 'encoding' },
                { name = 'location' },
                { name = 'progress' },
            },
        },
        winbar = {
            sigil = false,
            left = {
                { name = 'breadcrumbs', optional = true, opts = opts.breadcrumbs or {} },
            },
        },
        window_label = {
            sigil = false,
            placement = window_label_placement(config),
            right = {
                { name = 'diagnostics', opts = { empty = false, signs = true } },
                { name = 'git_diff' },
                {
                    name = 'filename',
                    opts = {
                        filetype_icon = true,
                        max_width = 48,
                        separate_flags = true,
                        modified_text = '[+]',
                        readonly_text = '[-]',
                        modified_hl = 'StatuesqueModifiedFilename',
                    },
                },
            },
            backend = {
                name = 'incline',
            },
        },
    }

    if tabulature_enabled then
        surfaces.tabline = {
            left = {
                { name = 'tabulature', opts = opts.tabulature_widget or {} },
            },
            right = {
                { name = 'cwd', opts = { max_width = opts.tabline_cwd_max_width or 48 } },
            },
            sigil = tabline_sigil,
        }
    else
        surfaces.tabline = {
            left = {
                { name = 'cwd', opts = { max_width = opts.tabline_cwd_max_width or 48 } },
            },
        }
    end

    return surfaces
end

--- @param default? statuesque.SurfaceConfig|false
--- @param override? statuesque.SurfaceConfig|false
--- @return statuesque.SurfaceConfig|false
local function merge_surface_config(default, override)
    if override == false then
        return false
    end
    if type(override) == 'table' and override.enabled == false then
        return false
    end
    if default == false or default == nil then
        return override or {}
    end
    if override == nil then
        return default
    end

    local merged = vim.tbl_deep_extend('force', default, override)
    if override.left ~= nil then
        merged.left = override.left
    end
    if override.right ~= nil then
        merged.right = override.right
    end
    if override.backend ~= nil then
        merged.backend = override.backend
    end
    return merged
end

--- @param config? statuesque.Config
--- @return table<string, statuesque.SurfaceConfig|false>
local function surface_configs(config)
    config = config or {}
    local name = preset_name(config)
    if name ~= nil and name ~= false and name ~= true and name ~= 'default' then
        error(('unsupported Statuesque preset: %s'):format(name))
    end
    local seed_defaults = config.preset ~= false and not (config.preset == nil and config.surfaces ~= nil)
    local configs = seed_defaults and default_surface_configs(config) or {}
    local overrides = type(config.surfaces) == 'table' and config.surfaces or {}

    for surface, override in pairs(overrides) do
        configs[surface] = merge_surface_config(configs[surface], override)
    end
    if type(configs.window_label) == 'table' then
        apply_window_label_config(config, configs.window_label)
    end

    return configs
end

--- @param surface string
--- @param config statuesque.SurfaceConfig
--- @return statuesque.SurfaceBackendConfig[]
local function backend_configs(surface, config)
    local backend = config.backend
    if backend == false then
        return {}
    end
    if backend == nil and surface == 'window_label' then
        return { { name = 'incline' } }
    end
    if backend == nil then
        return { { name = surface } }
    end
    if type(backend) == 'string' then
        return { { name = backend } }
    end
    if type(backend) ~= 'table' then
        error(('invalid backend config for surface %s'):format(surface))
    end

    if backend.name ~= nil or backend.target ~= nil or backend.opts ~= nil then
        return { backend }
    end

    --- @type statuesque.SurfaceBackendConfig[]
    local backends = {}
    for _, item in ipairs(backend) do
        if type(item) == 'string' then
            backends[#backends + 1] = { name = item }
        elseif type(item) == 'table' then
            backends[#backends + 1] = item
        else
            error(('invalid backend list entry for surface %s'):format(surface))
        end
    end
    return backends
end

--- @param surface string
--- @param config statuesque.SurfaceConfig
--- @return statuesque.SurfaceBackendConfig
local function primary_backend(surface, config)
    return backend_configs(surface, config)[1] or { name = surface }
end

--- @param surface string
--- @param config statuesque.SurfaceConfig
--- @return statuesque.RenderSpec
local function surface_widgets(surface, config)
    if config.left ~= nil or config.right ~= nil then
        return {
            left = config.left or {},
            right = config.right,
        }
    end
    if #config > 0 then
        return config
    end
    error(('surface %s must define left/right widgets'):format(surface))
end

--- @param surface string
--- @param config statuesque.SurfaceConfig
--- @param global_config statuesque.Config
--- @return statuesque.RenderNode
local function compose_surface(surface, config, global_config)
    local backend = primary_backend(surface, config)
    local widgets = surface_widgets(surface, config)
    local opts = compose_opts(global_config, config, surface, config.sigil)

    if is_single_sided_backend(surface, backend) and (config.left == nil) ~= (config.right == nil) then
        opts.side = config.right ~= nil and 'right' or 'left'
        widgets = config.right or config.left or {}
    end

    return style.compose(widgets, opts)
end

--- @param opts? table
--- @param side statuesque.Side
local function apply_incline_side(opts, side)
    opts.window = opts.window or {}
    opts.window.placement = opts.window.placement or {}
    opts.window.margin = opts.window.margin or {}
    local horizontal = opts.window.placement.horizontal
    if horizontal ~= nil and horizontal ~= side then
        error(('incline placement.horizontal=%s conflicts with surface %s side'):format(horizontal, side))
    end
    opts.window.placement.horizontal = side

    if opts.window.margin.horizontal == nil then
        opts.window.margin.horizontal = side == 'right' and { left = 1, right = 0 } or { left = 0, right = 1 }
    end
    if opts.window.padding == nil then
        opts.window.padding = side == 'right' and { left = 1, right = 0 } or { left = 0, right = 1 }
    end
end

--- @param supported any
--- @param vertical? statuesque.VerticalPlacement
--- @return boolean
local function vertical_placement_supported(supported, vertical)
    if vertical == nil then
        return true
    end
    if supported == vertical then
        return true
    end
    if type(supported) ~= 'table' then
        return false
    end
    if supported[vertical] == true then
        return true
    end
    for _, value in ipairs(supported) do
        if value == vertical then
            return true
        end
    end
    return false
end

--- @param surface string
--- @param backend_name string
--- @param capabilities statuesque.BackendCapabilities?
--- @param placement? statuesque.SurfacePlacement
local function validate_vertical_placement(surface, backend_name, capabilities, placement)
    local vertical = placement and placement.vertical
    if vertical == nil then
        return
    end
    local supported = type(capabilities) == 'table' and capabilities.placement and capabilities.placement.vertical
        or nil
    if not vertical_placement_supported(supported, vertical) then
        error(
            ('backend %s does not support vertical placement %s for surface %s'):format(backend_name, vertical, surface)
        )
    end
end

--- @param opts table
--- @param placement? statuesque.SurfacePlacement
local function apply_incline_placement(opts, placement)
    local vertical = placement and placement.vertical
    if vertical == nil then
        return
    end

    opts.window = opts.window or {}
    opts.window.placement = opts.window.placement or {}
    local configured = opts.window.placement.vertical
    if configured ~= nil and configured ~= vertical then
        error(
            ('incline placement.vertical=%s conflicts with surface vertical placement %s'):format(configured, vertical)
        )
    end
    opts.window.placement.vertical = vertical
end

--- @param surface string
--- @param config statuesque.SurfaceConfig
--- @param backend statuesque.SurfaceBackendConfig
--- @return string
local function backend_target(surface, config, backend)
    if backend.target ~= nil then
        return backend.target
    end
    return backend.name or surface
end

--- @param targets any
--- @param target string
--- @return boolean
local function target_supported(targets, target)
    if type(targets) ~= 'table' then
        return false
    end
    if targets[target] == true then
        return true
    end
    for _, value in ipairs(targets) do
        if value == target then
            return true
        end
    end
    return false
end

--- @param surface string
--- @param name string
--- @param backend statuesque.SurfaceBackendConfig
local function validate_backend_target(surface, name, backend)
    if backend.target == nil then
        return
    end

    local capabilities = require('statuesque.backend').capabilities(name)
    if type(capabilities) ~= 'table' or not target_supported(capabilities.targets, backend.target) then
        error(('backend %s does not support target %s for surface %s'):format(name, backend.target, surface))
    end
end

--- @param surface string
--- @param config statuesque.SurfaceConfig
--- @param backend statuesque.SurfaceBackendConfig
local function validate_backend(surface, config, backend)
    local name = backend.name or surface
    validate_backend_target(surface, name, backend)
    validate_vertical_placement(surface, name, require('statuesque.backend').capabilities(name), config.placement)
    if name == 'incline' and config.left ~= nil and config.right ~= nil then
        error(('surface %s cannot define both left and right for incline backend'):format(surface))
    end
end

--- @param configs table<string, statuesque.SurfaceConfig|false>
local function validate_backend_targets(configs)
    local seen = {}
    for surface, config in pairs(configs) do
        if config ~= false then
            for _, backend in ipairs(backend_configs(surface, config)) do
                validate_backend(surface, config, backend)
                local name = backend.name or surface
                local target = backend_target(surface, config, backend)
                local key = name .. ':' .. target
                if seen[key] ~= nil then
                    error(
                        ('surfaces %s and %s both render to backend %s target %s'):format(
                            seen[key],
                            surface,
                            name,
                            target
                        )
                    )
                end
                seen[key] = surface
            end
        end
    end
end

--- Build the default preset surfaces without installing them.
--- @param config? statuesque.Config
--- @return table<string, statuesque.RenderNode>
function M.surfaces(config)
    config = config or {}
    local configs = surface_configs(config)
    validate_backend_targets(configs)

    local surfaces = {}
    for surface, surface_config in pairs(configs) do
        if surface_config ~= false then
            surfaces[surface] = compose_surface(surface, surface_config, config)
        end
    end
    return surfaces
end

--- @param surface string
--- @param config statuesque.SurfaceConfig
--- @param backend statuesque.SurfaceBackendConfig
local function install_backend(surface, config, backend)
    local name = backend.name or surface
    local target = backend_target(surface, config, backend)
    if name == 'statusline' or name == 'tabline' or name == 'winbar' then
        require('statuesque').install_surface(surface, target)
        return
    end

    if name == 'incline' then
        local side = config.right ~= nil and 'right' or 'left'
        local opts = vim.deepcopy(backend.opts or {})
        apply_incline_side(opts, side)
        apply_incline_placement(opts, config.placement)
        require('statuesque.integrations.incline').setup(vim.tbl_extend('force', backend, { opts = opts }), surface)
        return
    end
end

--- Install the default preset surfaces.
--- @param config? statuesque.Config
--- @return table<string, statuesque.RenderNode>
function M.install(config)
    config = config or {}
    local statuesque = require('statuesque')
    local configs = surface_configs(config)
    validate_backend_targets(configs)

    local surfaces = {}
    for surface, surface_config in pairs(configs) do
        if surface_config ~= false then
            surfaces[surface] = compose_surface(surface, surface_config, config)
            statuesque.set_surface(surface, surfaces[surface])
        end
    end

    for surface, surface_config in pairs(configs) do
        if surface_config ~= false then
            for _, backend in ipairs(backend_configs(surface, surface_config)) do
                install_backend(surface, surface_config, backend)
            end
        end
    end

    return surfaces
end

return M

--- @class EventDescriptor the descriptor of an event
--- @field event string
--- @field pattern string

--- @alias EventDescription string|EventDescriptor

--- @alias Callback<T> fun(winnr: integer, bufnr: integer):T
--- @alias EnabledCallback Callback<boolean>
--- @alias RenderCallback Callback<RenderResult>

--- @alias HighlightDefinition { link: string }|{ fg?: string, bg?: string }
--- @alias HighlightDescription string|string[]|HighlightDefinition|HighlightDefinition[]

--- @alias ClickHandler string|function|{ id: string, args?: table }

--- @class RenderNode
--- @field text? string
--- @field hl? HighlightDescription
--- @field style? table<string, any>
--- @field children? RenderNode[]
--- @field on_click? ClickHandler
--- @field id? string
--- @field role? string
--- @field priority? integer
--- @field min_width? integer
--- @field max_width? integer
--- @field truncate? 'left'|'right'|'middle'|'hide'
--- @field target? 'statusline'|'tabline'|'winbar'|'incline'|'custom'

--- @alias RenderResult string|string[]|RenderNode|RenderNode[]

--- @class CacheOptions
--- @field cache.invalidate_on EventDescription|EventDescription[]
--- @field cache_mode "window"|"buffer"|"global"

--- @class ComponentReference a reference to a component defined in a module
--- @field name string the name of the module, will be used as `require('statuesque.components.' .. name)`
--- @field opts? table<string, any>

--- @class ComponentDefinition the definition of a component
--- @field use? ComponentReference
--- @field enabled? boolean|EnabledCallback a condition whether to enable this section
--- @field children? Component[]
--- @field cache? CacheOptions
--- @field init? Callback<nil>
--- @field render? RenderCallback

--- @alias Component ComponentReference|ComponentDefinition

--- @class Section: ComponentDefinition a definition of a section
--- @field alignment? "left"|"center"|"right"

--- @class Target the configuration of a specific target
--- @field enabled? boolean|EnabledCallback a condition whether to enable this target
--- @field sections? Section[] a list of sections for this target

--- @class Configuration the configuration of the plugin
--- @field targets? table<string, Target> a map from a target name to its configuration
local default_config = {
    targets = {},
}

local M = {}

--- @type Configuration
M.config = default_config

--- Replace current configuration with the default config extended by `config`.
--- @param config Configuration? the configuration to extend the default config with.
function M.configure(config)
    M.config = vim.tbl_deep_extend('force', default_config, config or {})
end

return M

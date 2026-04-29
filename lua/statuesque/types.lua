--- LuaLS type declarations for Statuesque's public Lua API.
--- This module intentionally has no runtime behavior.

--- @alias statuesque.Surface 'statusline'|'tabline'|'winbar'|'incline'|string
--- @alias statuesque.Target 'debug'|'text'|'vim'|'statusline'|'tabline'|'winbar'|'incline'|string
--- @alias statuesque.Side 'left'|'right'
--- @alias statuesque.Alignment 'left'|'center'|'right'
--- @alias statuesque.TruncateMode 'left'|'right'|'middle'|'hide'
--- @alias statuesque.SegmentLayout 'adjacent'|'gapped'|string
--- @alias statuesque.StyleName 'slanted'|'capsule'|string
--- @alias statuesque.SeparatorKind 'section'|'inner'|'in_section'|string
--- @alias statuesque.ModeName 'normal'|'insert'|'visual'|'replace'|'command'|'terminal'|string
--- @alias statuesque.RenderScope 'global'|'window'|'buffer'|string

--- @class statuesque.HighlightSpec
--- @field fg? string GUI foreground color.
--- @field bg? string GUI background color.
--- @field sp? string GUI special color.
--- @field link? string Highlight group link.
--- @field bold? boolean
--- @field italic? boolean
--- @field underline? boolean
--- @field undercurl? boolean
--- @field underdouble? boolean
--- @field underdotted? boolean
--- @field underdashed? boolean
--- @field strikethrough? boolean
--- @field reverse? boolean
--- @field nocombine? boolean

--- @alias statuesque.Highlight string|statuesque.HighlightSpec|statuesque.Highlight[]

--- @class statuesque.ClickActionObject
--- @field id string Controller-specific action identifier.
--- @field args? table Controller-specific action arguments.

--- @alias statuesque.ClickAction string|fun(payload: table): any|statuesque.ClickActionObject

--- @class statuesque.CachePolicy
--- @field enabled? boolean
--- @field key? any
--- @field invalidate_on? string|table|string[]
--- @field cache_mode? 'window'|'buffer'|'global'|string

--- @alias statuesque.CacheConfig boolean|statuesque.CachePolicy

--- @class statuesque.RenderContext
--- @field target? statuesque.Target
--- @field surface? statuesque.Surface
--- @field side? statuesque.Side
--- @field separator_side? statuesque.Side
--- @field backend_defaults? statuesque.BackendDefaults
--- @field style? statuesque.StyleName
--- @field context? table
--- @field on_update? fun(component: statuesque.PublisherComponent)
--- @field inline_highlight_prefix? string
--- @field inline_highlight_index? integer
--- @field inline_highlight_definitions? { name: string, hl: statuesque.HighlightSpec }[]
--- @field render_scope? statuesque.RenderScope
--- @field cache_scope? statuesque.RenderScope
--- @field winid? integer
--- @field win_id? integer
--- @field window? integer
--- @field winnr? integer
--- @field bufnr? integer
--- @field buf? integer
--- @field buffer? integer
--- @field [string] any

--- @class statuesque.RenderNode
--- @field text? string|number|boolean
--- @field raw? string|number|boolean
--- @field align? statuesque.Alignment
--- @field hl? statuesque.Highlight
--- @field style? table<string, any>
--- @field children? statuesque.RenderSpec|statuesque.RenderSpec[]
--- @field render? fun(context?: statuesque.RenderContext, self?: statuesque.RenderNode): statuesque.RenderSpec
--- @field cache? statuesque.CacheConfig
--- @field separator? statuesque.SeparatorKind
--- @field separator_side? statuesque.Side
--- @field separator_text? string
--- @field custom_rendered? boolean When true, composed bars pass this node through without generated section separators.
--- @field on_click? statuesque.ClickAction
--- @field id? string
--- @field role? string
--- @field priority? integer
--- @field min_width? integer
--- @field max_width? integer
--- @field truncate? statuesque.TruncateMode
--- @field target? statuesque.Target
--- @field _statuesque_cache_key? any
--- @field [integer] statuesque.RenderSpec
--- @field [string] any

--- @class statuesque.NormalizedNode: statuesque.RenderNode
--- @field text? string
--- @field raw? string
--- @field children? statuesque.NormalizedNode[]

--- @alias statuesque.RenderFunction fun(context?: statuesque.RenderContext): statuesque.RenderSpec
--- @alias statuesque.RenderSpec nil|false|string|number|boolean|statuesque.RenderNode|statuesque.RenderSpec[]|statuesque.RenderFunction|statuesque.PublisherComponent

--- @class statuesque.PublisherComponent
--- @field statuesque_component? boolean
--- @field capabilities? table
--- @field cache? statuesque.CacheConfig
--- @field value? statuesque.RenderSpec
--- @field render? fun(self: statuesque.PublisherComponent, context?: statuesque.RenderContext): statuesque.RenderSpec
--- @field subscribe? fun(self: statuesque.PublisherComponent, notify: fun()): any
--- @field statuesque_render? fun(self: statuesque.PublisherComponent, context?: statuesque.RenderContext): statuesque.RenderSpec
--- @field statuesque_subscribe? fun(self: statuesque.PublisherComponent, notify: fun()): any

--- @class statuesque.BackendCapabilities
--- @field target? statuesque.Target
--- @field snapshot? boolean
--- @field highlights? boolean|'preserved'|'groups'|string
--- @field clicks? boolean|'preserved'|string
--- @field click_degradation? string
--- @field align? boolean|'preserved'|string
--- @field raw? boolean|'preserved'|string
--- @field install? boolean
--- @field global_statusline? boolean
--- @field render_scope? statuesque.RenderScope
--- @field window_context? boolean
--- @field buffer_context? boolean
--- @field degradation_metadata? boolean
--- @field [string] any

--- @class statuesque.Backend
--- @field render fun(render_spec: statuesque.RenderSpec, opts?: statuesque.RenderContext): any
--- @field capabilities? statuesque.BackendCapabilities

--- @class statuesque.BackendDefaults
--- @field sigil? string|false
--- @field tabulature_sigil? string
--- @field sigil_hl? statuesque.Highlight
--- @field left_separator? string
--- @field right_separator? string
--- @field inner_left_separator? string
--- @field inner_right_separator? string
--- @field separator_padding? string
--- @field sigil_leading_padding? string
--- @field sigil_padding? string
--- @field gap_padding? string
--- @field right_gapped_separator? 'left'|'right'|string
--- @field side? statuesque.Side
--- @field base? statuesque.HighlightSpec
--- @field outer? statuesque.HighlightSpec
--- @field inner? statuesque.HighlightSpec
--- @field inner_mix? number
--- @field [string] any

--- @class statuesque.ComposeOptions: statuesque.RenderContext
--- @field surface? statuesque.Surface
--- @field target? statuesque.Target
--- @field sigil? string|false
--- @field sigil_hl? statuesque.Highlight
--- @field segment_layout? statuesque.SegmentLayout
--- @field layout? statuesque.SegmentLayout
--- @field gap_padding? string
--- @field base? statuesque.HighlightSpec
--- @field outer? statuesque.HighlightSpec
--- @field inner? statuesque.HighlightSpec
--- @field inner_mix? number
--- @field mode_style? boolean|string|statuesque.HighlightSpec
--- @field mode? string
--- @field min_contrast? number
--- @field minimum_contrast? number
--- @field readable_dark? string
--- @field readable_light? string
--- @field hard_readable_dark? string
--- @field hard_readable_light? string
--- @field backend_defaults? statuesque.BackendDefaults
--- @field side? statuesque.Side
--- @field separator_side? statuesque.Side
--- @field trailing_separator? boolean
--- @field right_leading_separator? boolean
--- @field leading_separator? boolean
--- @field context? table
--- @field [string] any

--- @class statuesque.ComponentSides
--- @field left? statuesque.RenderSpec[]
--- @field right? statuesque.RenderSpec[]

--- @alias statuesque.ComposeInput statuesque.RenderSpec[]|statuesque.ComponentSides

--- @class statuesque.PublishConfig
--- @field auto? boolean|table<string, boolean>

--- @class statuesque.TargetConfig
--- @field enabled? boolean|fun(winnr: integer, bufnr: integer): boolean
--- @field sections? table[]

--- @class statuesque.Config
--- @field targets? table<string, statuesque.TargetConfig>
--- @field style? statuesque.StyleName
--- @field preset? boolean|statuesque.PresetOptions
--- @field manifold? boolean|statuesque.ManifoldAutoOptions
--- @field publish? statuesque.PublishConfig

--- @alias statuesque.SetupConfig statuesque.Config
--- @alias statuesque.Provider statuesque.RenderSpec|fun(context?: statuesque.RenderContext): statuesque.RenderSpec

--- @class statuesque.PresetOptions: statuesque.ComposeOptions
--- @field tabulature? boolean
--- @field status_icon? string
--- @field status_sigil? string|false
--- @field tabline_sigil? string|false
--- @field winbar_sigil? string|false
--- @field tabulature_opts? table
--- @field tabline_cwd_max_width? integer

--- @class statuesque.WidgetModeOptions
--- @field icon? string
--- @field cache_key? any

--- @class statuesque.WidgetFilenameOptions
--- @field path? string
--- @field modified_text? string
--- @field readonly_text? string
--- @field max_width? integer

--- @class statuesque.WidgetDiagnosticsOptions
--- @field labels? table<integer, string>
--- @field empty? boolean
--- @field empty_text? string

--- @class statuesque.WidgetIconOptions
--- @field icon? string
--- @field max_width? integer

--- @class statuesque.WidgetCwdOptions
--- @field path? string
--- @field max_width? integer

--- @class statuesque.WidgetStaticOptions
--- @field role? string
--- @field hl? statuesque.Highlight

--- @class statuesque.WidgetTabulatureOptions
--- @field tree_opts? table
--- @field local_actions? boolean Enable direct local Neovim tabpage actions for locally sourced Tabulature state.
--- @field [string] any

--- @class statuesque.ManifoldHostOptions
--- @field surface? string
--- @field install? boolean

--- @class statuesque.ManifoldChildOptions
--- @field surface? string
--- @field suppress_local? boolean

--- @class statuesque.ManifoldAutoOptions
--- @field host? false|statuesque.ManifoldHostOptions
--- @field child? false|statuesque.ManifoldChildOptions
--- @field max_attempts? integer

return {}

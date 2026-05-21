--- LuaLS type declarations for Statuesque's public Lua API.
--- This module intentionally has no runtime behavior.

--- @alias statuesque.Surface 'statusline'|'tabline'|'winbar'|'incline'|string
--- @alias statuesque.Target 'debug'|'text'|'vim'|'statusline'|'tabline'|'winbar'|'incline'|string
--- @alias statuesque.Side 'left'|'right'
--- @alias statuesque.VerticalPlacement 'top'|'bottom'
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

--- @class statuesque.HoverActionObject
--- @field id string Controller-specific action identifier.
--- @field args? table Controller-specific action arguments.

--- @alias statuesque.HoverPhase 'enter'|'move'|'leave'|string
--- @alias statuesque.HoverAction string|fun(payload: table): any|statuesque.HoverActionObject

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
--- @field placement? statuesque.SurfacePlacement
--- @field backend_defaults? statuesque.BackendDefaults
--- @field style? statuesque.StyleName
--- @field context? table
--- @field on_update? fun(component: statuesque.PublisherComponent)
--- @field inline_highlight_prefix? string
--- @field inline_highlight_index? integer
--- @field inline_highlight_definitions? { name: string, hl: statuesque.HighlightSpec }[]
--- @field render_scope? statuesque.RenderScope
--- @field _statuesque_installed_render? boolean Internal marker for Neovim-owned surface evaluations.
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
--- @field exact_highlight? boolean Preserve explicit foreground colors through composed-section contrast repair.
--- @field on_click? statuesque.ClickAction
--- @field on_hover? statuesque.HoverAction
--- @field id? string
--- @field role? string
--- @field priority? integer
--- @field min_width? integer
--- @field max_width? integer
--- @field truncate? statuesque.TruncateMode
--- @field target? statuesque.Target
--- @field _statuesque_cache_key? any
--- @field _statuesque_semantic_chrome? statuesque.HighlightSpec
--- @field [integer] statuesque.RenderSpec
--- @field [string] any

--- @class statuesque.NormalizedNode: statuesque.RenderNode
--- @field text? string
--- @field raw? string
--- @field children? statuesque.NormalizedNode[]

--- @alias statuesque.RenderFunction fun(context?: statuesque.RenderContext): statuesque.RenderSpec
--- @alias statuesque.RenderSpec nil|false|string|number|boolean|statuesque.RenderNode|statuesque.WidgetReference|statuesque.RenderSpec[]|statuesque.RenderFunction|statuesque.PublisherComponent

--- @class statuesque.PublisherComponent
--- @field statuesque_component? boolean
--- @field capabilities? table
--- @field cache? statuesque.CacheConfig
--- @field value? statuesque.RenderSpec
--- @field render? fun(self: statuesque.PublisherComponent, context?: statuesque.RenderContext): statuesque.RenderSpec
--- @field subscribe? fun(self: statuesque.PublisherComponent, notify: fun()): any
--- @field statuesque_render? fun(self: statuesque.PublisherComponent, context?: statuesque.RenderContext): statuesque.RenderSpec
--- @field statuesque_subscribe? fun(self: statuesque.PublisherComponent, notify: fun()): any

--- @class statuesque.WidgetReference
--- @field name string Runtimepath widget module under `statuesque.widgets.<name>`.
--- @field optional? boolean Return no content instead of failing when the module is absent.
--- @field opts? table Options passed to the widget module factory.

--- @class statuesque.BackendCapabilities
--- @field target? statuesque.Target
--- @field snapshot? boolean
--- @field highlights? boolean|'preserved'|'groups'|string
--- @field clicks? boolean|'preserved'|string
--- @field click_degradation? string
--- @field hover? boolean|'preserved'|'registered'|string
--- @field hover_degradation? string
--- @field align? boolean|'preserved'|string
--- @field raw? boolean|'preserved'|string
--- @field install? boolean
--- @field targets? string[]|table<string, boolean>
--- @field global_statusline? boolean
--- @field placement? statuesque.PlacementCapabilities
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
--- @field edge_padding? string
--- @field sigil_leading_padding? string
--- @field sigil_padding? string
--- @field gap_padding? string
--- @field right_gapped_separator? 'left'|'right'|string
--- @field side? statuesque.Side
--- @field base? statuesque.HighlightSpec
--- @field outer? statuesque.HighlightSpec
--- @field inner? statuesque.HighlightSpec
--- @field inner_mix? number
--- @field placement_defaults? table<string, statuesque.BackendDefaults>
--- @field [string] any

--- @class statuesque.SurfacePlacement
--- @field vertical? statuesque.VerticalPlacement

--- @class statuesque.PlacementCapabilities
--- @field vertical? statuesque.VerticalPlacement|statuesque.VerticalPlacement[]|table<string, boolean>

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
--- @field semantic_min_contrast? number Minimum contrast for explicit child foreground accents. Defaults lower than generated text to preserve color identity.
--- @field accent_min_contrast? number Alias for semantic_min_contrast.
--- @field semantic_background? 'dark'|'light' Override for semantic repair bias. Defaults to `vim.o.background`.
--- @field readable_dark? string
--- @field readable_light? string
--- @field hard_readable_dark? string
--- @field hard_readable_light? string
--- @field palette? false|string[]|table<string, string>|fun(): string[]|table<string, string> Foreground harmony palette. Defaults to common highlight groups.
--- @field palette_distance_tolerance? number Maximum perceptual distance for preferring a palette color over an already-readable source foreground.
--- @field backend_defaults? statuesque.BackendDefaults
--- @field side? statuesque.Side
--- @field placement? statuesque.SurfacePlacement
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
--- @field placement? statuesque.SurfacePlacement

--- @class statuesque.WindowLabelConfig
--- @field placement? statuesque.SurfacePlacement
--- @field vertical? statuesque.VerticalPlacement
--- @field background? false|'transparent'|'none'|string|statuesque.HighlightSpec Base background under the label. Defaults to transparent.

--- @class statuesque.Config
--- @field targets? table<string, statuesque.TargetConfig>
--- @field style? statuesque.StyleName
--- @field palette? false|string[]|table<string, string>|fun(): string[]|table<string, string> Colors used to harmonize explicit child foregrounds with the active colorscheme.
--- @field preset? boolean|string|statuesque.PresetReference
--- @field surfaces? table<string, statuesque.SurfaceConfig|false>
--- @field window_label? statuesque.WindowLabelConfig
--- @field manifold? boolean|statuesque.ManifoldAutoOptions
--- @field publish? statuesque.PublishConfig

--- @alias statuesque.SetupConfig statuesque.Config
--- @alias statuesque.Provider statuesque.RenderSpec|fun(context?: statuesque.RenderContext): statuesque.RenderSpec

--- @class statuesque.PresetReference
--- @field [1]? string
--- @field opts? statuesque.PresetOptions

--- @class statuesque.PresetOptions
--- @field tabulature? boolean
--- @field mode? statuesque.WidgetModeOptions
--- @field tabulature_widget? table
--- @field git_repo? table
--- @field quickfix? statuesque.WidgetQuickfixOptions
--- @field dap? statuesque.WidgetDapOptions
--- @field breadcrumbs? statuesque.WidgetBreadcrumbsOptions
--- @field window_label? statuesque.WindowLabelConfig
--- @field tabline_cwd_max_width? integer

--- @class statuesque.SurfaceConfig: statuesque.ComposeOptions
--- @field left? statuesque.RenderSpec[]
--- @field right? statuesque.RenderSpec[]
--- @field backend? string|false|statuesque.SurfaceBackendConfig|statuesque.SurfaceBackendConfig[]
--- @field sigil? string|false
--- @field enabled? boolean
--- @field [integer] statuesque.RenderSpec

--- @class statuesque.SurfaceBackendConfig
--- @field name? string
--- @field target? string
--- @field opts? table

--- @class statuesque.WindowSurfaceReplacement
--- @field owner string Logical owner used for debugging and future lifecycle policies.
--- @field target string Window-local render target option to replace.
--- @field winid? integer Window that must currently display `bufnr`.
--- @field bufnr integer Buffer that owns the temporary replacement.
--- @field expression string Window-local target expression.
--- @field all_windows? boolean Replace the target in every window currently displaying `bufnr`.

--- @class statuesque.InclineIntegrationOptions
--- @field enabled? boolean
--- @field surface? string
--- @field opts? table

--- @class statuesque.WidgetModeOptions
--- @field icon? string

--- @class statuesque.WidgetFilenameOptions
--- @field path? string
--- @field modified_text? string
--- @field readonly_text? string
--- @field separate_flags? boolean Return filename and buffer-state flags as separate render nodes.
--- @field modified_hl? statuesque.Highlight Highlight applied to the filename node when the buffer is modified.
--- @field max_width? integer
--- @field filetype_icon? boolean|table Include the current buffer's filetype icon before the filename.
--- @field filetype_icon_separator? string Separator between the filetype icon and filename.

--- @class statuesque.WidgetDiagnosticsOptions
--- @field labels? table<integer, string>
--- @field signs? boolean
--- @field empty? boolean
--- @field empty_text? string

--- @class statuesque.WidgetIconOptions
--- @field icon? string
--- @field max_width? integer

--- @class statuesque.WidgetFiletypeOptions
--- @field icon? string|boolean
--- @field icon_separator? string
--- @field devicons? boolean

--- @class statuesque.WidgetCwdOptions
--- @field path? string
--- @field max_width? integer

--- @class statuesque.WidgetGitDiffOptions
--- @field labels? table<string, string>
--- @field highlights? table<string, string>
--- @field sources? (string|statuesque.WidgetGitDiffSource)[] Buffer-variable sources to inspect after Stratum.
--- @field stratum? boolean
--- @field empty? boolean
--- @field empty_text? string

--- @class statuesque.WidgetGitDiffSource
--- @field var string
--- @field path? string|integer|(string|integer)[]
--- @field keys? table<string, string|integer|(string|integer)[]>

--- @class statuesque.WidgetQuickfixOptions
--- @field kind? 'quickfix'|'location'|'loclist'|string
--- @field list? 'quickfix'|'location'|'loclist'|string
--- @field label? string
--- @field title? boolean
--- @field max_width? integer
--- @field hl? statuesque.Highlight
--- @field empty? boolean
--- @field empty_text? string

--- @class statuesque.WidgetDapOptions
--- @field icon? string
--- @field running_text? string
--- @field session_name? boolean
--- @field show_without_session? boolean
--- @field max_width? integer
--- @field hl? statuesque.Highlight
--- @field empty? boolean
--- @field empty_text? string

--- @class statuesque.WidgetBreadcrumbsOptions
--- @field provider? fun(context?: statuesque.RenderContext): statuesque.RenderSpec
--- @field separator? string
--- @field max_width? integer
--- @field truncate? statuesque.TruncateMode
--- @field empty? boolean
--- @field empty_text? string
--- @field navic? boolean
--- @field auto_attach? boolean Automatically attach `nvim-navic` to document-symbol LSP clients.
--- @field depth_limit? integer
--- @field depth_limit_indicator? string

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

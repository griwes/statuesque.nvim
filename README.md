# statuesque.nvim

A status display plugin for neovim, allowing a unified system of components to target the statusline, winbar, tabline, or other custom status displays (like incline.nvim).

## Current Scope

Statuesque is the render layer for the Manifold UI suite. It does not own tab,
domain, notification, cmdline, or status data; producer plugins emit recursive
render specs and Statuesque translates those specs into target-specific output.

## Render Spec

A render spec is a string, a segment table, a function returning a render spec, a publisher component, or a nested list of render specs.

```lua
local spec = {
    {
        id = 'domain:alpha',
        role = 'domain',
        hl = 'StatuesqueActiveDomain',
        on_click = { id = 'domain.select', args = { domain = 1 } },
        'Alpha',
        children = {
            { text = ' *', role = 'status' },
        },
    },
    ' ',
    { text = 'Beta', max_width = 12, truncate = 'right' },
}
```

Supported segment fields:

- `text`: literal text.
- `align`: semantic alignment markers, lowered by backends that support them.
- `raw`: backend-specific raw text. Prefer semantic fields such as `align`
  for portable render specs.
- `hl`: highlight group name or inline highlight definition.
- `style`: target-neutral style metadata for adapters that can use it.
- `children`: recursive child specs.
- `on_click`: function, function name, or semantic `{ id, args }` action.
- `on_hover`: function, function name, or semantic `{ id, args }` action. Targets
  must advertise whether this is supported, registered for later hit testing, or
  degraded.
- `id`: stable semantic id.
- `role`: producer-defined semantic role such as `domain`, `tab`, or `status`.
- `priority`, `min_width`, `max_width`, `truncate`: layout hints.
- `target`: optional target hint.
- `render`: function-backed element. The function receives the render context and returns a render spec.
- `cache`: cache policy. `true` or `{ key = ... }` caches both the normalized fragment and backend-rendered output until `statuesque.invalidate(key)`. Anonymous `cache = true` table components are keyed by table identity; use `{ key = ... }` when a cache should be shared across equivalent component instances.
- `separator`: backend-specific separator request such as `'section'` or `'inner'`.
- `name`: runtimepath widget reference. `{ name = 'git_repo', optional = true,
  opts = {...} }` loads `statuesque.widgets.git_repo` and renders the returned
  component. `optional = true` makes a missing widget render no content.

Publisher components are tables that advertise `statuesque_component = true`
and provide `render(context)` plus optional `subscribe(self, notify)`.
`notify()` invalidates the component cache and schedules a status redraw.

## Publication Policy

`statusline` is the only surface that auto-publishes to detected external
consumers by default. `tabline`, `winbar`, and custom surfaces require explicit
publication unless opted in:

```lua
require('statuesque').setup({
    publish = {
        auto = {
            statusline = true,
            tabline = true,
        },
    },
})
```

Manual publication is always available:

```lua
require('statuesque').publish('tabline')
```

The current external consumer is Manifold child status/surface export. Statuesque
still only publishes render specs; it does not own the underlying editor,
Tabulature, or Manifold state.

## Presets

```lua
require('statuesque').setup({
    manifold = false,
    preset = 'default',
    surfaces = {
        statusline = {
            left = {
                { name = 'mode' },
                { name = 'diagnostics', opts = { empty = false } },
                { name = 'git_repo', optional = true },
            },
            right = {
                { name = 'filetype' },
                { name = 'encoding' },
                { name = 'location' },
                { name = 'progress' },
            },
        },
        window_label = {
            left = {
                { name = 'filetype', opts = { icon_only = true } },
                { name = 'filename', opts = { max_width = 48 } },
            },
            backend = {
                name = 'incline',
                opts = {
                    window = {
                        placement = { vertical = 'bottom' },
                    },
                },
            },
        },
    },
})
```

The default preset installs a global statusline, tabline, and winbar. It uses a
section-style layout with interpolated styles instead of lualine's strict
`a/b/c/x/y/z` segment model. Built-in widgets cover mode, filename,
breadcrumbs, diagnostics, git branch, Git diff, filetype, location, progress,
cwd, and hostname. The default global statusline intentionally does not include the
current buffer filename; buffer identity belongs on window-local label surfaces,
while the winbar defaults to breadcrumbs/navigation context. The breadcrumbs
widget reads a buffer-local `vim.b.statuesque_breadcrumbs` value or delegates to
`nvim-navic`. When `nvim-navic` is present, the widget automatically attaches it
to document-symbol LSP clients, so user config only needs to install/configure
`nvim-navic` and select the breadcrumbs widget. Other plugins can ship
default-preset widgets, such as Tabulature's tabline component or Stratum's live
repository component, by adding `lua/statuesque/widgets/*.lua` modules to
runtimepath without moving their state logic into Statuesque.

Preset-specific widget options live under the preset selector:

```lua
require('statuesque').setup({
    preset = {
        'default',
        opts = {
            git_repo = { icon = 'G' },
            breadcrumbs = { max_width = 80 },
        },
    },
})
```

`statuesque.compose()` accepts either a simple component list or explicit
`{ left = {...}, right = {...} }` sections. Right sections are separated with
right-oriented glyphs and emit a leading right boundary separator by default.
By default, top-level sections render as gapped islands against the backend base
style: each segment enters from base with the reverse block separator, exits
back to base with the normal block separator, and keeps `separator = 'inner'`
for within-segment separation. Gapped section boundaries keep ordinary
`separator_padding` on the segment-colored side. Adjacent islands are separated
by `gap_padding`, which defaults to `''`. Set `segment_layout = 'adjacent'` to
use the older directly-adjacent section rendering.
Interpolated section styles enforce readable foreground/background contrast;
set `min_contrast` on the compose options to tune the threshold. When a
generated foreground is unreadable, Statuesque first tries softer dark/light
fallbacks before falling back to pure black or white.
Explicit child foregrounds, such as plugin-owned status colors or devicon
colors, are first matched to a Statuesque palette and then checked against the
inherited section background. Set `palette` at top-level setup or per compose
call to a list/map/function of `#rrggbb` colors. When no palette is configured,
Statuesque derives one from common highlight groups in the active colorscheme;
set `palette = false` to disable palette harmonization for a render.
Palette colors only replace a semantic foreground when they are perceptually
close enough to preserve the source color identity; otherwise Statuesque repairs
the original foreground toward a readable color with the same hue. Tune that
boundary with `palette_distance_tolerance`. Explicit child foregrounds use
`semantic_min_contrast` (default `3.5`) instead of the stricter generated-text
threshold, because many semantic accents cannot retain their color identity on
mode-reactive backgrounds at `4.5` contrast. Semantic foreground repair builds
exact, darker, and lighter candidate sets from both same-hue repairs and the
active palette, then picks one aggregate direction for a sibling widget run from
coverage, worst/best/average contrast, source-color identity, and congruence
with the editor background. Set `semantic_background = 'dark'` or `'light'` to
override the `vim.o.background` bias used by that scoring.
Statusline composition uses the current editor mode as its outer section style
by default; set `mode_style = false` to opt out. Other surfaces can opt in with
`mode_style = true` or a specific mode name. Mode styles are derived from
`lualine_a_<mode>` highlights when available and then contrast-checked against
the same readability policy used by interpolated sections. Generated styles
stop short of the pure inner color by default so the last segment still retains
some of the main outer color; set `inner_mix = 1` to use the pure inner
endpoint.
Default sigils use a fixed accent that is intentionally separate from the mode
highlight palette.
When `tabulature.nvim` is present, the default tabline consumes Tabulature's
Statuesque render specs and keeps the current working directory as right-side
context. Without Tabulature, the tabline falls back to a compact cwd bar.
The default preset also exposes a `window_label` surface for Incline-backed
per-window labels. When `incline.nvim` is installed, Statuesque can configure it
from `surfaces.window_label.backend` and render buffer-local identity from
Statuesque widgets instead of requiring a custom Incline render function in user
config. Surface configs use `left` and `right` widget runs. If no backend is
specified, a surface installs to the backend with the same name. Backends that
support only one side, such as `incline`, reject surfaces that define both
`left` and `right`.
Vim statusline-family targets lower the semantic alignment marker to `%=`.
Incline-style separators can be oriented with `{ side = 'left' }` or
`{ side = 'right' }` render/backend options.

Statuesque intentionally supports only Neovim's global statusline mode when it
installs a statusline; `install_surface(..., 'statusline')` always sets
`laststatus=3`.

## API

```lua
local statuesque = require('statuesque')

local normalized = statuesque.normalize(spec)
local plain = statuesque.render(spec, 'text')
local debug = statuesque.render(spec, 'debug')
local tabline = statuesque.render(spec, 'tabline')
local incline = statuesque.render(spec, 'incline')
local composed = statuesque.compose({
    { name = 'mode' },
    { name = 'filename' },
    { name = 'git_repo', optional = true },
}, {
    surface = 'statusline',
})

statuesque.register_provider('domains', function(context)
    return spec
end)

statuesque.set_surface('tabline', 'domains')
statuesque.install_surface('tabline', 'tabline')

local window_label = statuesque.render_surface('window_label', 'incline', {
    winid = vim.api.nvim_get_current_win(),
    bufnr = vim.api.nvim_get_current_buf(),
})

local capabilities = statuesque.backend_capabilities('statusline')
```

## Backend Authoring

Backends translate normalized render specs into a concrete target shape.
Custom backends are discovered from runtimepath modules. Put a module at
`lua/statuesque/backend/<name>.lua` and return a table with
`render(render_spec, opts)` plus optional `capabilities`; no backend registry or
registration lifecycle is required:

```lua
-- lua/statuesque/backend/my_surface.lua
return {
    capabilities = {
        render_scope = 'global',
        highlights = false,
        clicks = false,
        hover = false,
        align = false,
        raw = true,
        install = false,
    },
    render = function(render_spec, opts)
        return require('statuesque').render(render_spec, 'text', opts)
    end,
}
```

Then target it by name:

```lua
local rendered = require('statuesque').render(spec, 'my_surface')
```

The backend contract is intentionally narrow:

- `render(render_spec, opts)` is required.
- `capabilities` is optional and should describe what producer plugins may rely
  on before they render.
- Backends that can install themselves may expose an `install(surface, opts)`
  helper, but Statuesque only calls built-in installation helpers today.
- Invalid runtimepath modules fail with an explicit backend-contract error.

Capability fields should be explicit:

- `render_scope`: `'global'`, `'window'`, `'buffer'`, or another documented
  scope string.
- `window_context` and `buffer_context`: whether the backend can use window or
  buffer identity while rendering.
- `highlights`: `true`, `false`, `'preserved'`, `'groups'`, or another
  descriptive degradation string.
- `clicks`: `true`, `false`, `'preserved'`, or another descriptive degradation
  string.
- `hover`: `true`, `false`, `'preserved'`, `'registered'`, or another
  descriptive degradation string.
- `click_degradation` and `hover_degradation`: extra explanation when a target
  carries metadata but cannot dispatch the action.
- `raw`: whether backend-specific raw chunks are accepted.
- `align`: whether semantic alignment markers are supported.
- `install`: whether the target is installable through Statuesque.
- `targets`: optional table/list of supported backend targets. Built-in
  `statusline`, `tabline`, `winbar`, and `incline` do not expose extra targets,
  so `backend.target` is rejected for them.
- `degradation_metadata`: whether unsupported semantics are surfaced as
  metadata instead of being silently dropped.

## Targets

- `debug`: normalized Lua tables for tests and snapshots.
- `text`: plain text, useful for assertions and fallback displays.
- `statusline`, `tabline`, `winbar`, `vim`: Vim statusline-family syntax.
- `incline`: a limited Incline-style nested table. Highlight names become
  `group`; unsupported click semantics are preserved as explicit Statuesque
  metadata instead of being silently treated as working callbacks.

Click handlers in Vim statusline-family targets are routed through
`require('statuesque').click(...)`; semantic table handlers return a payload for
the caller, while function handlers are invoked directly.

`install_surface(surface, target)` installs a configured provider onto
`statusline`, `tabline`, or `winbar`. Statusline installs always use Neovim's
global statusline mode (`laststatus=3`).
Incline surfaces are not installed through `install_surface`; the default preset
uses `statuesque.integrations.incline` to configure `incline.nvim` when it is
available, with Statuesque still owning the render spec and cache behavior.

Backends advertise `capabilities`; built-in and runtimepath backends expose
those capabilities through `backend_capabilities(target)`. Unsupported target
behavior should degrade explicitly. For example, the Incline backend marks
unsupported click and hover handlers as Statuesque metadata instead of
pretending those callbacks work. The `text` backend drops highlight, click,
hover, and alignment semantics while preserving textual content and raw text.

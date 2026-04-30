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
    preset = true,
})
```

The default preset installs a global statusline, tabline, and winbar. It uses a
section-style layout with interpolated styles instead of lualine's strict
`a/b/c/x/y/z` segment model. Built-in widgets cover mode, filename, diagnostics,
git branch, filetype, location, progress, cwd, and hostname. Other plugins can
ship default-preset widgets, such as Tabulature's tabline component or Stratum's
live repository component, by adding `lua/statuesque/widgets/*.lua` modules to
runtimepath without moving their state logic into Statuesque.

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

local capabilities = statuesque.backend_capabilities('statusline')
```

## Backend Authoring

Backends translate normalized render specs into a concrete target shape. A
backend may be registered at runtime:

```lua
statuesque.register_backend('custom', {
    capabilities = {
        render_scope = 'global',
        highlights = false,
        clicks = false,
        hover = false,
        align = false,
        raw = false,
        install = false,
    },
    render = function(render_spec, opts)
        return statuesque.render(render_spec, 'text', opts)
    end,
})
```

Custom backends can also be shipped as runtimepath modules. Put a module at
`lua/statuesque/backend/<name>.lua` and return a table with
`render(render_spec, opts)` plus optional `capabilities`:

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

Backends advertise `capabilities`; built-in and runtimepath backends expose
those capabilities through `backend_capabilities(target)`. Unsupported target
behavior should degrade explicitly. For example, the Incline backend marks
unsupported click and hover handlers as Statuesque metadata instead of
pretending those callbacks work. The `text` backend drops highlight, click,
hover, and alignment semantics while preserving textual content and raw text.

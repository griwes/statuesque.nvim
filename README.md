# statuesque.nvim

A status display plugin for neovim, allowing a unified system of components to target the statusline, winbar, tabline, or other custom status displays (like incline.nvim).

## Current Scope

Statuesque is the render layer for the Manifold UI suite. It does not own tab,
domain, notification, cmdline, or status data; producer plugins emit recursive
render specs and Statuesque translates those specs into target-specific output.

## Render Spec

A render spec is a string, a segment table, or a nested list of render specs.

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
- `hl`: highlight group name or inline highlight definition.
- `style`: target-neutral style metadata for adapters that can use it.
- `children`: recursive child specs.
- `on_click`: function, function name, or semantic `{ id, args }` action.
- `id`: stable semantic id.
- `role`: producer-defined semantic role such as `domain`, `tab`, or `status`.
- `priority`, `min_width`, `max_width`, `truncate`: layout hints.
- `target`: optional target hint.

## API

```lua
local statuesque = require('statuesque')

local normalized = statuesque.normalize(spec)
local plain = statuesque.render(spec, 'text')
local debug = statuesque.render(spec, 'debug')
local tabline = statuesque.render(spec, 'tabline')
local incline = statuesque.render(spec, 'incline')

statuesque.register_provider('domains', function(context)
    return spec
end)

statuesque.set_surface('tabline', 'domains')
statuesque.install_surface('tabline', 'tabline')
```

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
`statusline`, `tabline`, or `winbar`. Statusline installs default to Neovim's
global statusline mode (`laststatus=3`) unless `globalstatus=false` is passed.

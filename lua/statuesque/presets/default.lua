local style = require('statuesque.style')
local widgets = require('statuesque.widgets')

local M = {}

local function has_tabulature()
    local ok = pcall(require, 'tabulature')
    return ok
end

function M.surfaces(opts)
    opts = opts or {}
    local tabulature_enabled = opts.tabulature == true or (opts.tabulature == nil and has_tabulature())
    local tabline_sigil
    if tabulature_enabled then
        tabline_sigil = style.backend_defaults('tabline').tabulature_sigil
    end

    local surfaces = {
        statusline = style.compose({
            left = {
                widgets.mode({ icon = opts.status_icon }),
                widgets.filename(),
                widgets.diagnostics({ empty = false }),
                widgets.git_branch(),
            },
            right = {
                widgets.filetype(),
                widgets.encoding(),
                widgets.location(),
                widgets.progress(),
            },
        }, {
            surface = 'statusline',
            sigil = opts.status_sigil,
        }),
        winbar = style.compose({
            widgets.filename({ path = ':~:.', max_width = 80 }),
        }, {
            surface = 'winbar',
            sigil = opts.winbar_sigil,
        }),
    }

    if tabulature_enabled then
        surfaces.tabline = style.compose({
            left = {
                widgets.tabulature(opts.tabulature_opts or {}),
            },
            right = {
                widgets.cwd({ max_width = opts.tabline_cwd_max_width or 48 }),
            },
        }, {
            surface = 'tabline',
            sigil = tabline_sigil or opts.tabline_sigil,
        })
    else
        surfaces.tabline = style.compose({
            widgets.cwd({ max_width = opts.tabline_cwd_max_width or 48 }),
        }, {
            surface = 'tabline',
            sigil = opts.tabline_sigil,
        })
    end

    return surfaces
end

function M.install(opts)
    local statuesque = require('statuesque')
    local surfaces = M.surfaces(opts)

    for surface, render_spec in pairs(surfaces) do
        statuesque.set_surface(surface, render_spec)
    end

    statuesque.install_surface('statusline', 'statusline')
    statuesque.install_surface('tabline', 'tabline')
    statuesque.install_surface('winbar', 'winbar')

    return surfaces
end

return M

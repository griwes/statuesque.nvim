local context = require('statuesque.context')
local vim_renderer = require('statuesque.render.vim')

local M = {}

--- Render a spec into Vim tabline syntax.
--- @param render_spec statuesque.RenderSpec
--- @param opts? statuesque.RenderContext
--- @return string
function M.render(render_spec, opts)
    return vim_renderer.render(render_spec, context.with_target(opts, 'tabline'))
end

return M

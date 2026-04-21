local vim_renderer = require('statuesque.render.vim')

local M = {}

--- Render a spec into Vim statusline syntax.
--- @param render_spec any
--- @param opts? table
--- @return string
function M.render(render_spec, opts)
    return vim_renderer.render(
        render_spec,
        vim.tbl_extend('force', opts or {}, {
            target = 'statusline',
        })
    )
end

return M

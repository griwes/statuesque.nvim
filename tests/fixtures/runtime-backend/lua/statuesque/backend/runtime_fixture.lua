local M = {}

M.capabilities = {
    render_scope = 'global',
    highlights = false,
    clicks = false,
    hover = false,
    hover_degradation = 'metadata',
    align = false,
    raw = true,
    install = false,
    fixture = true,
}

function M.render(render_spec, opts)
    local text = require('statuesque').render(render_spec, 'text', opts)
    return ('runtime-fixture:%s'):format(text)
end

return M

local M = {}

M.capabilities = {
    highlights = false,
    clicks = false,
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

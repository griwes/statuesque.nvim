local spec = require('statuesque.spec')

local M = {}

local function plain_value(value)
    if type(value) == 'function' then
        return '<function>'
    end

    if type(value) ~= 'table' then
        return value
    end

    local plain = {}
    for key, child in pairs(value) do
        plain[key] = plain_value(child)
    end
    return plain
end

--- Render a spec as a normalized Lua table suitable for snapshots.
--- @param render_spec any
--- @param opts? table
--- @return table[]
function M.render(render_spec, opts)
    return plain_value(spec.normalize(render_spec, opts))
end

return M

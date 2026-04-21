local spec = require('statuesque.spec')

local M = {}

local function render_node(node)
    local chunks = {}

    if node.text ~= nil then
        chunks[#chunks + 1] = node.text
    end

    if node.children ~= nil then
        for _, child in ipairs(node.children) do
            chunks[#chunks + 1] = render_node(child)
        end
    end

    return spec.truncate_text(table.concat(chunks), node)
end

--- Render a spec as plain text.
--- @param render_spec any
--- @param opts? table
--- @return string
function M.render(render_spec, opts)
    local nodes = spec.normalize(render_spec, opts)
    local chunks = {}

    for _, node in ipairs(nodes) do
        chunks[#chunks + 1] = render_node(node)
    end

    return table.concat(chunks)
end

return M

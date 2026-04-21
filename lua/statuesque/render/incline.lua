local spec = require('statuesque.spec')

local M = {}

local function copy_metadata(node)
    local metadata = {}

    if node.id ~= nil then
        metadata.id = node.id
    end
    if node.role ~= nil then
        metadata.role = node.role
    end
    if node.priority ~= nil then
        metadata.priority = node.priority
    end
    if node.target ~= nil then
        metadata.target = node.target
    end
    if node.on_click ~= nil then
        metadata.on_click = 'unsupported'
    end

    if next(metadata) == nil then
        return nil
    end

    return metadata
end

local function incline_group(hl)
    if type(hl) == 'string' then
        return hl
    end

    if type(hl) == 'table' and vim.tbl_islist and vim.tbl_islist(hl) then
        return incline_group(hl[#hl])
    end

    return nil
end

local function render_node(node)
    local chunks = {}

    if node.text ~= nil then
        chunks[#chunks + 1] = spec.truncate_text(node.text, node)
    end

    if node.children ~= nil then
        for _, child in ipairs(node.children) do
            chunks[#chunks + 1] = render_node(child)
        end
    end

    local group = incline_group(node.hl)
    local metadata = copy_metadata(node)

    if group == nil and metadata == nil and #chunks == 1 then
        return chunks[1]
    end

    local rendered = chunks
    if group ~= nil then
        rendered.group = group
    end
    if metadata ~= nil then
        rendered.statuesque = metadata
    end

    return rendered
end

--- Render a spec into a deliberately limited Incline-style nested table.
--- Unsupported semantic fields are preserved under `statuesque` metadata.
--- @param render_spec any
--- @param opts? table
--- @return table
function M.render(render_spec, opts)
    local rendered = {}
    for _, node in ipairs(spec.normalize(render_spec, opts)) do
        rendered[#rendered + 1] = render_node(node)
    end
    return rendered
end

return M

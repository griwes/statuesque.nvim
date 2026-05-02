local M = {}

---@param value any
---@return string
function M.encode_value(value)
    value = tostring(value or '')
    return ('%d:%s'):format(#value, value)
end

---@param hl? statuesque.Highlight
---@return string
local function highlight_variant(hl)
    if hl == nil then
        return ''
    end

    if type(hl) == 'string' then
        return 'group:' .. hl
    end

    if type(hl) ~= 'table' then
        return tostring(hl)
    end

    if vim.islist and vim.islist(hl) then
        local parts = {}
        for index, item in ipairs(hl) do
            parts[index] = highlight_variant(item)
        end
        return table.concat(parts, ',')
    end

    return table.concat({
        tostring(hl.fg or ''),
        tostring(hl.bg or ''),
        tostring(hl.sp or ''),
        tostring(hl.bold or ''),
        tostring(hl.italic or ''),
        tostring(hl.underline or ''),
        tostring(hl.undercurl or ''),
        tostring(hl.underdouble or ''),
        tostring(hl.underdotted or ''),
        tostring(hl.underdashed or ''),
        tostring(hl.strikethrough or ''),
        tostring(hl.reverse or ''),
        tostring(hl.nocombine or ''),
    }, ',')
end

---@param node statuesque.NormalizedNode
---@return string
function M.node_highlights(node)
    local parts = { highlight_variant(node.hl) }

    for _, child in ipairs(node.children or {}) do
        parts[#parts + 1] = M.node_highlights(child)
    end

    return table.concat(parts, '|')
end

return M

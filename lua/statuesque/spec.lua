local M = {}

local KNOWN_FIELDS = {
    'text',
    'hl',
    'style',
    'on_click',
    'id',
    'role',
    'priority',
    'min_width',
    'max_width',
    'truncate',
    'target',
}

local KNOWN_FIELD_SET = {}
for _, field in ipairs(KNOWN_FIELDS) do
    KNOWN_FIELD_SET[field] = true
end

local TRUNCATE_MODES = {
    left = true,
    right = true,
    middle = true,
    hide = true,
}

local function append_all(target, source)
    for _, item in ipairs(source) do
        target[#target + 1] = item
    end
end

local function has_known_field(value)
    for key in pairs(value) do
        if KNOWN_FIELD_SET[key] then
            return true
        end
    end

    return false
end

local function copy_table(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = copy_table(child)
    end
    return copy
end

local function normalize_children(value, opts)
    local children = {}

    for index = 1, #value do
        append_all(children, M.normalize(value[index], opts))
    end

    if value.children ~= nil then
        if type(value.children) == 'table' then
            for index = 1, #value.children do
                append_all(children, M.normalize(value.children[index], opts))
            end
        else
            append_all(children, M.normalize(value.children, opts))
        end
    end

    return children
end

local function normalize_segment(value, opts)
    local segment = {}

    if value.text ~= nil then
        segment.text = tostring(value.text)
    end

    for _, field in ipairs(KNOWN_FIELDS) do
        if field ~= 'text' and value[field] ~= nil then
            segment[field] = copy_table(value[field])
        end
    end

    if segment.truncate ~= nil and not TRUNCATE_MODES[segment.truncate] then
        error(('unsupported truncate mode: %s'):format(tostring(segment.truncate)))
    end

    local children = normalize_children(value, opts)
    if #children > 0 then
        segment.children = children
    end

    if segment.text == nil and segment.children == nil and not has_known_field(segment) then
        return {}
    end

    return { segment }
end

--- Normalize a recursive render specification into a canonical list of nodes.
--- @param render_spec any
--- @param opts? table
--- @return table[]
function M.normalize(render_spec, opts)
    opts = opts or {}

    if render_spec == nil or render_spec == false then
        return {}
    end

    local render_type = type(render_spec)
    if render_type == 'string' or render_type == 'number' or render_type == 'boolean' then
        return {
            {
                text = tostring(render_spec),
            },
        }
    end

    if render_type ~= 'table' then
        error(('unsupported render node type: %s'):format(render_type))
    end

    if not has_known_field(render_spec) then
        local children = normalize_children(render_spec, opts)
        if #children > 0 then
            return children
        end
    end

    return normalize_segment(render_spec, opts)
end

local function strchars(value)
    if vim and vim.fn and vim.fn.strchars then
        return vim.fn.strchars(value)
    end

    return #value
end

local function strcharpart(value, start, length)
    if vim and vim.fn and vim.fn.strcharpart then
        return vim.fn.strcharpart(value, start, length)
    end

    return value:sub(start + 1, start + length)
end

--- Apply a node's truncation policy to already-rendered text.
--- @param text string
--- @param node table
--- @return string
function M.truncate_text(text, node)
    if node.max_width == nil then
        return text
    end

    local max_width = math.max(0, tonumber(node.max_width) or 0)
    if strchars(text) <= max_width then
        return text
    end

    local mode = node.truncate or 'right'
    if mode == 'hide' or max_width == 0 then
        return ''
    end

    if max_width <= 3 then
        if mode == 'left' then
            return strcharpart(text, strchars(text) - max_width, max_width)
        end

        return strcharpart(text, 0, max_width)
    end

    if mode == 'left' then
        return '...' .. strcharpart(text, strchars(text) - max_width + 3, max_width - 3)
    end

    if mode == 'middle' then
        local left_width = math.floor((max_width - 3) / 2)
        local right_width = max_width - 3 - left_width
        return strcharpart(text, 0, left_width) .. '...' .. strcharpart(text, strchars(text) - right_width, right_width)
    end

    return strcharpart(text, 0, max_width - 3) .. '...'
end

return M

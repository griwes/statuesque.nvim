local M = {}
local cache = require('statuesque.cache')
local publisher = require('statuesque.publisher')

local KNOWN_FIELDS = {
    'text',
    'raw',
    'name',
    'optional',
    'opts',
    'align',
    'hl',
    'style',
    'on_click',
    'on_hover',
    'id',
    'role',
    'priority',
    'min_width',
    'max_width',
    'truncate',
    'target',
    'render',
    'cache',
    'separator',
    'separator_side',
    'custom_rendered',
    'exact_highlight',
    '_statuesque_cache_key',
    '_statuesque_widget_spec',
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

local WIDGET_REFERENCE_FIELDS = {
    name = true,
    optional = true,
    opts = true,
    _statuesque_widget_spec = true,
}

local SEGMENT_COPY_EXCLUDE_FIELDS = {
    text = true,
    raw = true,
    render = true,
    cache = true,
    _statuesque_widget_spec = true,
}

--- @param target table[]
--- @param source table[]
local function append_all(target, source)
    for _, item in ipairs(source) do
        target[#target + 1] = item
    end
end

--- @param value table
--- @return boolean
local function has_known_field(value)
    for key in pairs(value) do
        if KNOWN_FIELD_SET[key] then
            return true
        end
    end

    return false
end

--- @generic T
--- @param value T
--- @return T
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

--- @param value table
--- @return boolean
local function is_widget_reference(value)
    if type(value.name) ~= 'string' or value.name == '' then
        return false
    end

    for key in pairs(value) do
        if not WIDGET_REFERENCE_FIELDS[key] then
            return false
        end
    end

    return true
end

--- @param err any
--- @param module string
--- @return boolean
local function is_module_not_found(err, module)
    return tostring(err):find(("module '%s' not found"):format(module), 1, true) ~= nil
end

--- @param value table
--- @param opts statuesque.RenderContext
--- @return statuesque.NormalizedNode[]
local function normalize_widget_reference(value, opts)
    if value._statuesque_widget_spec ~= nil then
        return M.normalize(value._statuesque_widget_spec, opts)
    end

    local module = 'statuesque.widgets.' .. value.name
    local ok, provider_or_error = pcall(require, module)
    if not ok then
        if value.optional == true and is_module_not_found(provider_or_error, module) then
            return {}
        end
        error(provider_or_error)
    end

    if type(provider_or_error) ~= 'function' then
        error(('statuesque widget module %s must return a function'):format(module))
    end

    value._statuesque_widget_spec = provider_or_error(value.opts or {})
    return M.normalize(value._statuesque_widget_spec, opts)
end

--- @param value table
--- @param opts statuesque.RenderContext
--- @return statuesque.NormalizedNode[]
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

--- @param value table
--- @param opts statuesque.RenderContext
--- @return statuesque.NormalizedNode[]
local function normalize_segment(value, opts)
    local segment = {}

    if value.text ~= nil then
        segment.text = tostring(value.text)
    end
    if value.raw ~= nil then
        segment.raw = tostring(value.raw)
    end

    for _, field in ipairs(KNOWN_FIELDS) do
        if not SEGMENT_COPY_EXCLUDE_FIELDS[field] and value[field] ~= nil then
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

--- @param opts statuesque.RenderContext
--- @return statuesque.RenderContext
local function context_for(opts)
    return opts.context or opts
end

--- @param opts table
--- @param suffix? string
--- @return string
local function fallback_key(opts, suffix)
    opts.__statuesque_dynamic_index = (opts.__statuesque_dynamic_index or 0) + 1
    return ('%s:%d'):format(suffix or 'dynamic', opts.__statuesque_dynamic_index)
end

--- @param parent table
--- @param nodes statuesque.NormalizedNode[]
--- @return statuesque.NormalizedNode[]
local function inherit_fields(parent, nodes)
    if #nodes ~= 1 or type(nodes[1]) ~= 'table' then
        return nodes
    end

    local child = nodes[1]
    for _, field in ipairs(KNOWN_FIELDS) do
        if field ~= 'text' and field ~= 'raw' and field ~= 'children' and field ~= 'render' and field ~= 'cache' then
            if parent[field] ~= nil and child[field] == nil then
                child[field] = copy_table(parent[field])
            end
        end
    end

    return nodes
end

--- @param value statuesque.RenderFunction|statuesque.RenderNode|statuesque.PublisherComponent
--- @param opts statuesque.RenderContext
--- @param render fun(): statuesque.RenderSpec
--- @return statuesque.NormalizedNode[]
local function normalize_dynamic(value, opts, render)
    local key = cache.key_for(value, type(value) == 'table' and value.id or fallback_key(opts, 'component'), opts)
    if publisher.is_component(value) then
        --- @cast value statuesque.PublisherComponent
        publisher.ensure_subscription(value, key, opts)
    end

    return cache.get(key, function()
        local rendered = render()
        local nodes = M.normalize(rendered, opts)
        if type(value) == 'table' then
            nodes = inherit_fields(value, nodes)
        end
        if key ~= nil then
            if #nodes == 1 then
                nodes[1]._statuesque_cache_key = key
            elseif #nodes > 1 then
                nodes = {
                    {
                        role = 'cached-fragment',
                        _statuesque_cache_key = key,
                        children = nodes,
                    },
                }
            end
        end
        return nodes
    end)
end

--- Normalize a recursive render specification into a canonical list of nodes.
--- @param render_spec statuesque.RenderSpec
--- @param opts? statuesque.RenderContext
--- @return statuesque.NormalizedNode[]
function M.normalize(render_spec, opts)
    opts = opts or {}

    if render_spec == nil or render_spec == false then
        return {}
    end

    local render_type = type(render_spec)
    if render_type == 'function' then
        return normalize_dynamic(render_spec, opts, function()
            return render_spec(context_for(opts))
        end)
    end

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

    if publisher.is_component(render_spec) then
        --- @cast render_spec statuesque.PublisherComponent
        return normalize_dynamic(render_spec, opts, function()
            return publisher.render(render_spec, context_for(opts))
        end)
    end

    if is_widget_reference(render_spec) then
        return normalize_widget_reference(render_spec, opts)
    end

    if type(render_spec.render) == 'function' then
        --- @cast render_spec statuesque.RenderNode
        return normalize_dynamic(render_spec, opts, function()
            return render_spec.render(context_for(opts), render_spec)
        end)
    end

    if not has_known_field(render_spec) then
        local children = normalize_children(render_spec, opts)
        if #children > 0 then
            return children
        end
    end

    return normalize_segment(render_spec, opts)
end

--- @param value string
--- @return integer
local function strchars(value)
    if vim and vim.fn and vim.fn.strchars then
        return vim.fn.strchars(value)
    end

    return #value
end

--- @param value string
--- @param start integer
--- @param length integer
--- @return string
local function strcharpart(value, start, length)
    if vim and vim.fn and vim.fn.strcharpart then
        return vim.fn.strcharpart(value, start, length)
    end

    return value:sub(start + 1, start + length)
end

--- Apply a node's truncation policy to already-rendered text.
--- @param text string
--- @param node statuesque.NormalizedNode
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

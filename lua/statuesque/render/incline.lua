local cache = require('statuesque.cache')
local context = require('statuesque.context')
local spec = require('statuesque.spec')
local style = require('statuesque.style')

local M = {}

--- @param value any
--- @return string
local function encode_variant_value(value)
    value = tostring(value or '')
    return ('%d:%s'):format(#value, value)
end

--- @generic T
--- @param value T
--- @return T
local function copy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copied = {}
    for key, child in pairs(value) do
        copied[key] = copy(child)
    end
    return copied
end

--- @param ctx statuesque.RenderContext
--- @return string
local function defaults_variant(ctx)
    local defaults = ctx.backend_defaults or {}
    return table.concat({
        encode_variant_value(defaults.left_separator),
        encode_variant_value(defaults.right_separator),
        encode_variant_value(defaults.inner_left_separator),
        encode_variant_value(defaults.inner_right_separator),
        encode_variant_value(defaults.separator_padding),
        encode_variant_value(defaults.side),
    }, '|')
end

--- @param ctx statuesque.RenderContext
--- @return string
local function variant_key(ctx)
    return ('side=%s,separator_side=%s,defaults=%s'):format(
        ctx.side or '',
        ctx.separator_side or '',
        defaults_variant(ctx)
    )
end

--- @param node statuesque.NormalizedNode
--- @return table?
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
    if node.on_hover ~= nil then
        metadata.on_hover = 'unsupported'
    end

    if next(metadata) == nil then
        return nil
    end

    return metadata
end

--- @param hl? statuesque.Highlight
--- @return string?
local function incline_group(hl)
    if type(hl) == 'string' then
        return hl
    end

    if type(hl) == 'table' and vim.islist and vim.islist(hl) then
        return incline_group(hl[#hl])
    end

    return nil
end

local render_node

--- @param node statuesque.NormalizedNode
--- @param ctx statuesque.RenderContext
--- @return string|table
local function render_node_uncached(node, ctx)
    local chunks = {}

    if node.text ~= nil then
        chunks[#chunks + 1] = spec.truncate_text(node.text, node)
    elseif node.raw ~= nil then
        chunks[#chunks + 1] = node.raw
    elseif node.align ~= nil then
        chunks[#chunks + 1] = ''
    elseif node.separator ~= nil then
        chunks[#chunks + 1] = style.separator_text(node.separator, 'incline', ctx)
    end

    if node.children ~= nil then
        for _, child in ipairs(node.children) do
            chunks[#chunks + 1] = render_node(child, ctx)
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

--- @param node statuesque.NormalizedNode
--- @param ctx statuesque.RenderContext
--- @return string|table
function render_node(node, ctx)
    return copy(cache.get_rendered(ctx.target, node._statuesque_cache_key, variant_key(ctx), function()
        return render_node_uncached(node, ctx)
    end))
end

--- Render a spec into a deliberately limited Incline-style nested table.
--- Unsupported semantic fields are preserved under `statuesque` metadata.
--- @param render_spec statuesque.RenderSpec
--- @param opts? statuesque.RenderContext
--- @return any[]
function M.render(render_spec, opts)
    local ctx = context.with_target(opts, 'incline')
    local rendered = {}
    for _, node in ipairs(spec.normalize(render_spec, ctx)) do
        rendered[#rendered + 1] = render_node(node, ctx)
    end
    return rendered
end

return M

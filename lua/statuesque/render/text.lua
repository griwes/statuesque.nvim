local cache = require('statuesque.cache')
local context = require('statuesque.context')
local spec = require('statuesque.spec')
local style = require('statuesque.style')

local M = {}

local render_node

--- @param value any
--- @return string
local function encode_variant_value(value)
    value = tostring(value or '')
    return ('%d:%s'):format(#value, value)
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
        encode_variant_value(defaults.edge_padding),
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
--- @param ctx statuesque.RenderContext
--- @return string
local function render_node_uncached(node, ctx)
    local chunks = {}

    if node.text ~= nil then
        chunks[#chunks + 1] = node.text
    elseif node.raw ~= nil then
        chunks[#chunks + 1] = node.raw
    elseif node.align ~= nil then
        chunks[#chunks + 1] = ''
    elseif node.separator ~= nil then
        chunks[#chunks + 1] = style.separator_text(node.separator, 'text', ctx)
    end

    if node.children ~= nil then
        for _, child in ipairs(node.children) do
            chunks[#chunks + 1] = render_node(child, ctx)
        end
    end

    return spec.truncate_text(table.concat(chunks), node)
end

--- @param node statuesque.NormalizedNode
--- @param ctx statuesque.RenderContext
--- @return string
function render_node(node, ctx)
    return cache.get_rendered(ctx.target, node._statuesque_cache_key, variant_key(ctx), function()
        return render_node_uncached(node, ctx)
    end)
end

--- Render a spec as plain text.
--- @param render_spec statuesque.RenderSpec
--- @param opts? statuesque.RenderContext
--- @return string
function M.render(render_spec, opts)
    local ctx = context.with_target(opts, 'text')
    local nodes = spec.normalize(render_spec, ctx)
    local chunks = {}

    for _, node in ipairs(nodes) do
        chunks[#chunks + 1] = render_node(node, ctx)
    end

    return table.concat(chunks)
end

return M

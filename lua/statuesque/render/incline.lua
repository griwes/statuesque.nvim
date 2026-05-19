local cache = require('statuesque.cache')
local context = require('statuesque.context')
local highlights = require('statuesque.render.highlights')
local render_variant = require('statuesque.render.variant')
local spec = require('statuesque.spec')
local style = require('statuesque.style')

local M = {}
local HIGHLIGHT_NAMESPACE = vim.api.nvim_create_namespace('statuesque.incline')

local function define_window_highlights()
    for _, group in ipairs({ 'Normal', 'NormalFloat', 'InclineNormal', 'InclineNormalNC', 'EndOfBuffer' }) do
        vim.api.nvim_set_hl(HIGHLIGHT_NAMESPACE, group, { bg = 'NONE' })
    end
end

define_window_highlights()

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
        render_variant.encode_value(defaults.left_separator),
        render_variant.encode_value(defaults.right_separator),
        render_variant.encode_value(defaults.inner_left_separator),
        render_variant.encode_value(defaults.inner_right_separator),
        render_variant.encode_value(defaults.separator_padding),
        render_variant.encode_value(defaults.side),
    }, '|')
end

--- @param ctx statuesque.RenderContext
--- @param node statuesque.NormalizedNode
--- @return string
local function variant_key(ctx, node)
    return ('side=%s,separator_side=%s,inline=%s,inline_start=%d,defaults=%s,hl=%s'):format(
        ctx.side or '',
        ctx.separator_side or '',
        ctx.inline_highlight_prefix or '',
        ctx.inline_highlight_index or 0,
        defaults_variant(ctx),
        render_variant.node_highlights(node)
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

    local group = highlights.name(node.hl, ctx)
    -- incline.nvim treats every non-numeric table key without `group` as an
    -- inline highlight definition. Structured metadata is therefore only safe
    -- on nodes that already have an explicit group.
    local source_metadata = copy_metadata(node)
    local metadata = group ~= nil and source_metadata or nil

    if group == nil and source_metadata == nil and #chunks == 1 then
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
    local inline_highlight_start = ctx.inline_highlight_index
    local inline_definition_start = #ctx.inline_highlight_definitions
    --- @type { rendered: string|table, inline_highlight_count?: integer, inline_highlight_definitions?: { name: string, hl: statuesque.HighlightSpec }[] }
    local record = cache.get_rendered(ctx.target, node._statuesque_cache_key, variant_key(ctx, node), function()
        local rendered = render_node_uncached(node, ctx)
        local inline_highlight_count = ctx.inline_highlight_index - inline_highlight_start
        return {
            rendered = rendered,
            inline_highlight_count = inline_highlight_count,
            inline_highlight_definitions = highlights.capture(ctx, inline_definition_start),
        }
    end)

    if type(record) ~= 'table' or record.rendered == nil then
        return copy(record)
    end

    ctx.inline_highlight_index = inline_highlight_start + (record.inline_highlight_count or 0)
    highlights.apply(record)
    return copy(record.rendered)
end

--- @param item any
--- @param inherited_group? string
--- @param inherited_metadata? table
--- @param output table[]
local function flatten_item(item, inherited_group, inherited_metadata, output)
    if type(item) == 'string' or type(item) == 'number' then
        local text = tostring(item)
        if text == '' then
            return
        end
        if inherited_group == nil and inherited_metadata == nil then
            output[#output + 1] = text
            return
        end

        local rendered = { text }
        if inherited_group ~= nil then
            rendered.group = inherited_group
        end
        if inherited_metadata ~= nil then
            rendered.statuesque = inherited_metadata
        end
        output[#output + 1] = rendered
        return
    end

    if type(item) ~= 'table' then
        return
    end

    local group = item.group or inherited_group
    local metadata = item.statuesque or inherited_metadata
    for _, child in ipairs(item) do
        flatten_item(child, group, metadata, output)
    end
end

--- @param items table[]
--- @return table[]
local function flatten_items(items)
    local flattened = {}
    for _, item in ipairs(items) do
        flatten_item(item, nil, nil, flattened)
    end
    return flattened
end

--- Render a spec into a deliberately limited Incline-style nested table.
--- Unsupported semantic fields are preserved under `statuesque` metadata.
--- @param render_spec statuesque.RenderSpec
--- @param opts? statuesque.RenderContext
--- @return any[]
function M.render(render_spec, opts)
    opts = opts or {}
    opts.inline_highlight_namespace = opts.inline_highlight_namespace or HIGHLIGHT_NAMESPACE
    local prefix = opts and opts.winid and ('StatuesqueInclineW%s_'):format(opts.winid) or 'StatuesqueIncline'
    local ctx = highlights.with_context(context.with_target(opts, 'incline'), opts, prefix)
    local rendered = {}
    for _, node in ipairs(spec.normalize(render_spec, ctx)) do
        rendered[#rendered + 1] = render_node(node, ctx)
    end
    return flatten_items(rendered)
end

--- @return integer
function M.highlight_namespace()
    return HIGHLIGHT_NAMESPACE
end

function M.define_window_highlights()
    define_window_highlights()
end

return M

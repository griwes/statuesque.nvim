local cache = require('statuesque.cache')
local clicks = require('statuesque.clicks')
local context = require('statuesque.context')
local hovers = require('statuesque.hovers')
local spec = require('statuesque.spec')
local style = require('statuesque.style')

local M = {}

--- @param text string
--- @return string
local function escape_text(text)
    local escaped = text:gsub('%%', '%%%%')
    return escaped
end

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
        encode_variant_value(defaults.side),
    }, '|')
end

--- @param ctx statuesque.RenderContext
--- @return string
local function variant_key(ctx)
    return ('side=%s,separator_side=%s,inline=%s,inline_start=%d,defaults=%s'):format(
        ctx.side or '',
        ctx.separator_side or '',
        ctx.inline_highlight_prefix or '',
        ctx.inline_highlight_index or 0,
        defaults_variant(ctx)
    )
end

--- @param ctx statuesque.RenderContext
--- @param name string
--- @param hl statuesque.HighlightSpec
local function record_inline_highlight(ctx, name, hl)
    ctx.inline_highlight_definitions[#ctx.inline_highlight_definitions + 1] = {
        name = name,
        hl = hl,
    }
end

--- @param record table
local function apply_inline_highlights(record)
    if type(record.inline_highlight_definitions) ~= 'table' then
        return
    end

    for _, definition in ipairs(record.inline_highlight_definitions) do
        vim.api.nvim_set_hl(0, definition.name, definition.hl)
    end
end

--- @param hl? statuesque.Highlight
--- @param ctx statuesque.RenderContext
--- @return string?
local function highlight_name(hl, ctx)
    if hl == nil then
        return nil
    end

    if type(hl) == 'string' then
        return hl
    end

    if type(hl) ~= 'table' then
        return nil
    end

    if vim.islist and vim.islist(hl) then
        return highlight_name(hl[#hl], ctx)
    end

    ctx.inline_highlight_index = ctx.inline_highlight_index + 1
    local name = ('%s%d'):format(ctx.inline_highlight_prefix, ctx.inline_highlight_index)
    vim.api.nvim_set_hl(0, name, hl)
    record_inline_highlight(ctx, name, hl)
    return name
end

local render_node

--- @param node statuesque.NormalizedNode
--- @param ctx statuesque.RenderContext
--- @return string
local function node_prefix(node, ctx)
    if node.text ~= nil then
        return escape_text(spec.truncate_text(node.text, node))
    end
    if node.raw ~= nil then
        return spec.truncate_text(node.raw, node)
    end
    if node.align == 'right' then
        return '%='
    end
    if node.align ~= nil then
        return ''
    end
    if node.separator ~= nil then
        return escape_text(spec.truncate_text(style.separator_text(node.separator, ctx.target, ctx), node))
    end
    return ''
end

--- @param node statuesque.NormalizedNode
--- @param ctx statuesque.RenderContext
--- @return string
local function render_node_uncached(node, ctx)
    local prefix = node_prefix(node, ctx)
    local chunks = { prefix }
    hovers.advance(ctx, prefix)

    if node.children ~= nil then
        for _, child in ipairs(node.children) do
            chunks[#chunks + 1] = render_node(child, ctx)
        end
    end

    local rendered = table.concat(chunks)
    if rendered == '' then
        return ''
    end

    local hl = highlight_name(node.hl, ctx)
    if hl ~= nil then
        rendered = ('%%#%s#%s%%*'):format(hl, rendered)
    end

    if node.on_click ~= nil then
        local click_id, function_name = clicks.register(node.on_click, {
            node = node,
            target = ctx.target,
        })
        rendered = ('%%%d@%s@%s%%T'):format(click_id, function_name, rendered)
    end

    return rendered
end

--- @param node statuesque.NormalizedNode
--- @param ctx statuesque.RenderContext
--- @return string
function render_node(node, ctx)
    local hover_start_col = ctx._statuesque_hover_col or 0
    local hover_span_start = hovers.span_count(ctx)
    local inline_highlight_start = ctx.inline_highlight_index
    local inline_definition_start = #ctx.inline_highlight_definitions
    --- @type { rendered: string, inline_highlight_count?: integer, inline_highlight_definitions?: { name: string, hl: statuesque.HighlightSpec }[], hover_width?: integer, hover_spans?: table[] }
    local record, from_cache = cache.get_rendered(ctx.target, node._statuesque_cache_key, variant_key(ctx), function()
        local rendered = render_node_uncached(node, ctx)
        local inline_highlight_count = ctx.inline_highlight_index - inline_highlight_start
        local definitions = {}

        for index = inline_definition_start + 1, #ctx.inline_highlight_definitions do
            definitions[#definitions + 1] = ctx.inline_highlight_definitions[index]
        end

        return {
            rendered = rendered,
            inline_highlight_count = inline_highlight_count,
            inline_highlight_definitions = definitions,
            hover_width = (ctx._statuesque_hover_col or hover_start_col) - hover_start_col,
            hover_spans = hovers.capture_relative(ctx, hover_span_start, hover_start_col),
        }
    end)

    if type(record) ~= 'table' or record.rendered == nil then
        return tostring(record or '')
    end

    if from_cache then
        hovers.replay_relative(ctx, record.hover_spans, hover_start_col)
        ctx._statuesque_hover_col = hover_start_col + (record.hover_width or hovers.display_width(record.rendered))
    end

    if node.on_hover ~= nil then
        hovers.record_span(ctx, node.on_hover, {
            node = node,
            target = ctx.target,
        }, hover_start_col, ctx._statuesque_hover_col or hover_start_col)
    end

    ctx.inline_highlight_index = inline_highlight_start + (record.inline_highlight_count or 0)
    apply_inline_highlights(record)
    return record.rendered
end

--- Render a spec into Vim statusline/tabline/winbar syntax.
--- @param render_spec statuesque.RenderSpec
--- @param opts? statuesque.RenderContext
--- @return string
function M.render(render_spec, opts)
    local ctx = vim.tbl_extend('force', context.with_target(opts, opts and opts.target or 'vim'), {
        inline_highlight_index = 0,
        inline_highlight_prefix = opts and opts.inline_highlight_prefix or 'StatuesqueInline',
        inline_highlight_definitions = {},
    })

    hovers.begin_render(ctx)

    local chunks = {}
    for _, node in ipairs(spec.normalize(render_spec, ctx)) do
        local rendered = render_node(node, ctx)
        if rendered ~= '' then
            chunks[#chunks + 1] = rendered
        end
    end

    local rendered = table.concat(chunks)
    hovers.finish_render(ctx)
    return rendered
end

return M

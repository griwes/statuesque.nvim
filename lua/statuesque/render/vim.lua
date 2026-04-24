local cache = require('statuesque.cache')
local clicks = require('statuesque.clicks')
local spec = require('statuesque.spec')
local style = require('statuesque.style')

local M = {}

local function escape_text(text)
    local escaped = text:gsub('%%', '%%%%')
    return escaped
end

local function defaults_variant(ctx)
    local defaults = ctx.backend_defaults or {}
    return table.concat({
        defaults.left_separator or '',
        defaults.right_separator or '',
        defaults.inner_left_separator or '',
        defaults.inner_right_separator or '',
        defaults.separator_padding or '',
    }, ',')
end

local function variant_key(ctx)
    return ('side=%s,separator_side=%s,inline=%s,inline_start=%d,defaults=%s'):format(
        ctx.side or '',
        ctx.separator_side or '',
        ctx.inline_highlight_prefix or '',
        ctx.inline_highlight_index or 0,
        defaults_variant(ctx)
    )
end

local function record_inline_highlight(ctx, name, hl)
    ctx.inline_highlight_definitions[#ctx.inline_highlight_definitions + 1] = {
        name = name,
        hl = hl,
    }
end

local function apply_inline_highlights(record)
    if type(record.inline_highlight_definitions) ~= 'table' then
        return
    end

    for _, definition in ipairs(record.inline_highlight_definitions) do
        vim.api.nvim_set_hl(0, definition.name, definition.hl)
    end
end

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

local function render_node_uncached(node, ctx)
    local chunks = { node_prefix(node, ctx) }

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

function render_node(node, ctx)
    local inline_highlight_start = ctx.inline_highlight_index
    local inline_definition_start = #ctx.inline_highlight_definitions
    local record = cache.get_rendered(ctx.target, node._statuesque_cache_key, variant_key(ctx), function()
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
        }
    end)

    if type(record) ~= 'table' or record.rendered == nil then
        return record
    end

    ctx.inline_highlight_index = inline_highlight_start + (record.inline_highlight_count or 0)
    apply_inline_highlights(record)
    return record.rendered
end

--- Render a spec into Vim statusline/tabline/winbar syntax.
--- @param render_spec any
--- @param opts? table
--- @return string
function M.render(render_spec, opts)
    opts = opts or {}

    local ctx = vim.tbl_extend('force', opts, {
        target = opts.target or 'vim',
        inline_highlight_index = 0,
        inline_highlight_prefix = opts.inline_highlight_prefix or 'StatuesqueInline',
        inline_highlight_definitions = {},
    })

    local rendered_nodes = {}
    for _, node in ipairs(spec.normalize(render_spec, opts)) do
        rendered_nodes[#rendered_nodes + 1] = {
            node = node,
            rendered = render_node(node, ctx),
        }
    end

    local chunks = {}
    for _, entry in ipairs(rendered_nodes) do
        if entry.rendered ~= '' then
            chunks[#chunks + 1] = entry.rendered
        end
    end

    return table.concat(chunks)
end

return M

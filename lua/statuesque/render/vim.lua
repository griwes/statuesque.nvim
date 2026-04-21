local clicks = require('statuesque.clicks')
local spec = require('statuesque.spec')

local M = {}

local function escape_text(text)
    return text:gsub('%%', '%%%%')
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

    if vim.tbl_islist and vim.tbl_islist(hl) then
        return highlight_name(hl[#hl], ctx)
    end

    ctx.inline_highlight_index = ctx.inline_highlight_index + 1
    local name = ('%s%d'):format(ctx.inline_highlight_prefix, ctx.inline_highlight_index)
    vim.api.nvim_set_hl(0, name, hl)
    return name
end

local function render_node(node, ctx)
    local chunks = {}

    if node.text ~= nil then
        chunks[#chunks + 1] = node.text
    end

    if node.children ~= nil then
        for _, child in ipairs(node.children) do
            chunks[#chunks + 1] = render_node(child, ctx)
        end
    end

    local rendered = escape_text(spec.truncate_text(table.concat(chunks), node))

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

--- Render a spec into Vim statusline/tabline/winbar syntax.
--- @param render_spec any
--- @param opts? table
--- @return string
function M.render(render_spec, opts)
    opts = opts or {}

    local ctx = {
        target = opts.target or 'vim',
        inline_highlight_index = 0,
        inline_highlight_prefix = opts.inline_highlight_prefix or 'StatuesqueInline',
    }

    local chunks = {}
    for _, node in ipairs(spec.normalize(render_spec, opts)) do
        chunks[#chunks + 1] = render_node(node, ctx)
    end

    return table.concat(chunks)
end

return M

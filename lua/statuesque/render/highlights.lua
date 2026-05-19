local M = {}

--- @param ctx statuesque.RenderContext
--- @return integer
local function namespace(ctx)
    return tonumber(ctx.inline_highlight_namespace) or 0
end

--- @param ctx statuesque.RenderContext
--- @param name string
--- @param hl statuesque.HighlightSpec
local function record(ctx, name, hl)
    ctx.inline_highlight_definitions[#ctx.inline_highlight_definitions + 1] = {
        name = name,
        namespace = namespace(ctx),
        hl = hl,
    }
end

--- @param ctx statuesque.RenderContext
--- @param opts? statuesque.RenderContext
--- @param prefix string
--- @return statuesque.RenderContext
function M.with_context(ctx, opts, prefix)
    return vim.tbl_extend('force', ctx, {
        inline_highlight_index = opts and opts.inline_highlight_index or 0,
        inline_highlight_prefix = opts and opts.inline_highlight_prefix or prefix,
        inline_highlight_definitions = {},
    })
end

--- @param hl? statuesque.Highlight
--- @param ctx statuesque.RenderContext
--- @return string?
function M.name(hl, ctx)
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
        return M.name(hl[#hl], ctx)
    end

    ctx.inline_highlight_index = ctx.inline_highlight_index + 1
    local name = ('%s%d'):format(ctx.inline_highlight_prefix, ctx.inline_highlight_index)
    vim.api.nvim_set_hl(namespace(ctx), name, hl)
    record(ctx, name, hl)
    return name
end

--- @param ctx statuesque.RenderContext
--- @param start integer
--- @return { name: string, hl: statuesque.HighlightSpec }[]
function M.capture(ctx, start)
    local definitions = {}

    for index = start + 1, #ctx.inline_highlight_definitions do
        definitions[#definitions + 1] = ctx.inline_highlight_definitions[index]
    end

    return definitions
end

--- @param record table
function M.apply(record)
    if type(record.inline_highlight_definitions) ~= 'table' then
        return
    end

    for _, definition in ipairs(record.inline_highlight_definitions) do
        vim.api.nvim_set_hl(tonumber(definition.namespace) or 0, definition.name, definition.hl)
    end
end

return M

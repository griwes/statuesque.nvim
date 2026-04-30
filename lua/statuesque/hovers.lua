local M = {
    _next_id = 1,
    _handlers = {},
    _surfaces = {},
    _active = {},
    _installed_targets = {},
    _mousemove_installed = false,
}

--- @param surface string
--- @param target string
--- @return string
local function surface_key(surface, target)
    return ('%s:%s'):format(target, surface)
end

--- @param value any
--- @return string
local function strip_vim_statusline_syntax(value)
    local text = tostring(value or '')
    text = text:gsub('%%#.-#', '')
    text = text:gsub('%%%*', '')
    text = text:gsub('%%%d+@.-@', '')
    text = text:gsub('%%T', '')
    text = text:gsub('%%=', '')
    text = text:gsub('%%<', '')
    text = text:gsub('%%%%', '%%')
    return text
end

--- Return the display width of rendered Vim statusline-family text.
--- @param value any
--- @return integer
function M.display_width(value)
    local text = strip_vim_statusline_syntax(value)
    if text == '' then
        return 0
    end

    if vim and vim.fn and type(vim.fn.strdisplaywidth) == 'function' then
        local ok, width = pcall(vim.fn.strdisplaywidth, text)
        if ok and type(width) == 'number' then
            return width
        end
    end

    return #text
end

--- Register a hoverable render node.
--- @param handler statuesque.HoverAction
--- @param context? table
--- @return integer id
function M.register(handler, context)
    local id = M._next_id
    M._next_id = M._next_id + 1
    M._handlers[id] = {
        handler = handler,
        context = context or {},
    }

    return id
end

--- @param ctx statuesque.RenderContext
--- @return boolean
local function should_collect(ctx)
    return type(ctx) == 'table' and ctx._statuesque_hover_collect == true
end

--- @param ctx statuesque.RenderContext
--- @param text any
function M.advance(ctx, text)
    if not should_collect(ctx) then
        return
    end
    ctx._statuesque_hover_col = (ctx._statuesque_hover_col or 0) + M.display_width(text)
end

--- @param ctx statuesque.RenderContext
--- @return integer
function M.span_count(ctx)
    if not should_collect(ctx) or type(ctx._statuesque_hover_spans) ~= 'table' then
        return 0
    end
    return #ctx._statuesque_hover_spans
end

--- @param ctx statuesque.RenderContext
--- @param start_index integer
--- @param start_col integer
--- @return table[]
function M.capture_relative(ctx, start_index, start_col)
    if not should_collect(ctx) or type(ctx._statuesque_hover_spans) ~= 'table' then
        return {}
    end

    local captured = {}
    for index = start_index + 1, #ctx._statuesque_hover_spans do
        local span = ctx._statuesque_hover_spans[index]
        captured[#captured + 1] = {
            handler = span.handler,
            context = span.context,
            start_col = span.start_col - start_col,
            end_col = span.end_col - start_col,
        }
    end
    return captured
end

--- @param ctx statuesque.RenderContext
--- @param relative_spans table[]?
--- @param start_col integer
function M.replay_relative(ctx, relative_spans, start_col)
    if not should_collect(ctx) or type(relative_spans) ~= 'table' then
        return
    end

    for _, span in ipairs(relative_spans) do
        local id = M.register(span.handler, span.context)
        ctx._statuesque_hover_spans[#ctx._statuesque_hover_spans + 1] = {
            id = id,
            handler = span.handler,
            context = span.context,
            surface = ctx.surface,
            target = ctx.target,
            start_col = start_col + span.start_col,
            end_col = start_col + span.end_col,
        }
    end
end

--- Record a hover span for the current render node without changing the cursor.
--- @param ctx statuesque.RenderContext
--- @param handler statuesque.HoverAction
--- @param context? table
--- @param start_col integer
--- @param end_col integer
--- @return integer id
function M.record_span(ctx, handler, context, start_col, end_col)
    local id = M.register(handler, context)
    if should_collect(ctx) and end_col > start_col then
        ctx._statuesque_hover_spans[#ctx._statuesque_hover_spans + 1] = {
            id = id,
            handler = handler,
            context = context or {},
            surface = ctx.surface,
            target = ctx.target,
            start_col = start_col + 1,
            end_col = end_col,
        }
    end
    return id
end

--- Start collecting hover spans for a rendered installed surface.
--- @param ctx statuesque.RenderContext
function M.begin_render(ctx)
    if type(ctx.surface) ~= 'string' or type(ctx.target) ~= 'string' then
        return
    end

    ctx._statuesque_hover_collect = true
    ctx._statuesque_hover_col = 0
    ctx._statuesque_hover_spans = {}
end

--- Store hover spans produced by a rendered installed surface.
--- @param ctx statuesque.RenderContext
function M.finish_render(ctx)
    if not should_collect(ctx) then
        return
    end

    M._surfaces[surface_key(ctx.surface, ctx.target)] = {
        surface = ctx.surface,
        target = ctx.target,
        spans = ctx._statuesque_hover_spans or {},
    }
end

--- @param handler string
--- @param payload table
--- @return any
local function call_string_handler(handler, payload)
    if type(_G[handler]) == 'function' then
        return _G[handler](payload)
    end

    if vim and vim.fn and type(vim.fn[handler]) == 'function' then
        return vim.fn[handler](payload)
    end

    return nil
end

--- Dispatch a hover previously registered by a renderer.
--- @param id integer|string
--- @param phase? statuesque.HoverPhase
--- @param context? table
--- @return any
function M.dispatch(id, phase, context)
    local numeric_id = tonumber(id)
    local record = numeric_id and M._handlers[numeric_id] or nil
    if record == nil then
        return nil
    end

    local payload = vim.tbl_extend('force', record.context or {}, context or {}, {
        id = numeric_id,
        phase = phase or 'move',
    })

    if type(record.handler) == 'function' then
        return record.handler(payload)
    end

    if type(record.handler) == 'string' then
        return call_string_handler(record.handler, payload)
    end

    if type(record.handler) == 'table' then
        payload.action = record.handler.id
        payload.args = record.handler.args
    end

    return payload
end

--- @param surface string
--- @param target string
--- @param column integer
--- @return table?
local function span_at(surface, target, column)
    local surface_record = M._surfaces[surface_key(surface, target)]
    if surface_record == nil then
        return nil
    end

    for _, span in ipairs(surface_record.spans or {}) do
        if column >= span.start_col and column <= span.end_col then
            return span
        end
    end

    return nil
end

--- @param context? table
--- @param keep_key? string
local function leave_active(context, keep_key)
    for key, span in pairs(M._active) do
        if key ~= keep_key then
            local payload = vim.tbl_extend('force', context or {}, {
                surface = span.surface,
                target = span.target,
            })
            M.dispatch(span.id, 'leave', payload)
            M._active[key] = nil
        end
    end
end

--- Dispatch hover enter/move/leave for a rendered surface column.
--- @param surface string
--- @param target string
--- @param column integer
--- @param row? integer
--- @param context? table
--- @return any
function M.dispatch_position(surface, target, column, row, context)
    local key = surface_key(surface, target)
    local next_span = span_at(surface, target, column)
    local previous = M._active[key]
    local payload = vim.tbl_extend('force', context or {}, {
        surface = surface,
        target = target,
        row = row,
        col = column,
        column = column,
    })

    leave_active(payload, key)

    if previous ~= nil and (next_span == nil or previous.id ~= next_span.id) then
        M.dispatch(previous.id, 'leave', payload)
    end

    if next_span == nil then
        M._active[key] = nil
        return nil
    end

    M._active[key] = next_span
    payload.span = {
        start_col = next_span.start_col,
        end_col = next_span.end_col,
    }

    if previous == nil or previous.id ~= next_span.id then
        return M.dispatch(next_span.id, 'enter', payload)
    end

    return M.dispatch(next_span.id, 'move', payload)
end

--- @param target string
--- @param pos table
--- @return string?
local function installed_surface_for_position(target, pos)
    if target == 'winbar' and pos.winid ~= nil then
        return M._installed_targets.winbar
    end
    return M._installed_targets[target]
end

--- @param pos? table
--- @return any
function M.handle_mousemove(pos)
    pos = pos or vim.fn.getmousepos()
    local row = tonumber(pos.screenrow or pos.row or 0) or 0
    local col = tonumber(pos.screencol or pos.column or pos.col or 0) or 0
    local target

    if M._installed_targets.tabline ~= nil and row == 1 and vim.o.showtabline ~= 0 then
        target = 'tabline'
    elseif M._installed_targets.winbar ~= nil and tonumber(pos.winrow or 0) == 1 then
        target = 'winbar'
    elseif M._installed_targets.statusline ~= nil and row >= (vim.o.lines - vim.o.cmdheight) then
        target = 'statusline'
    end

    if target == nil or col <= 0 then
        leave_active({
            row = row,
            col = col,
            column = col,
            mouse = pos,
        })
        return nil
    end

    local surface = installed_surface_for_position(target, pos)
    if surface == nil then
        leave_active({
            row = row,
            col = col,
            column = col,
            mouse = pos,
        })
        return nil
    end

    return M.dispatch_position(surface, target, col, row, {
        mouse = pos,
    })
end

local function install_mousemove_mapping()
    if M._mousemove_installed then
        return
    end
    M._mousemove_installed = true

    vim.o.mousemoveevent = true
    vim.keymap.set({ 'n', 'i', 'v', 'x', 's', 'o', 'c' }, '<MouseMove>', function()
        M.handle_mousemove()
        return '<Ignore>'
    end, {
        expr = true,
        silent = true,
        desc = 'Dispatch Statuesque hover handlers',
    })
end

--- Register an installed statusline-family surface for mousemove hit testing.
--- @param surface string
--- @param target 'statusline'|'tabline'|'winbar'
function M.install_surface(surface, target)
    M._installed_targets[target] = surface
    install_mousemove_mapping()
end

return M

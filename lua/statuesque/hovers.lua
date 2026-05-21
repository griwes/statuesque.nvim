local M = {
    _next_id = 1,
    _handlers = {},
    _surfaces = {},
    _active = {},
    _installed_targets = {},
    _mousemove_installed = false,
    _previous_mousemoveevent = nil,
    _window_hooks_installed = false,
    _mousemoveevent_hook_installed = false,
    _mousemoveevent_owned = false,
    _changing_mousemoveevent = false,
}

local MOUSEMOVE_NAMESPACE = vim.api.nvim_create_namespace('statuesque.mousemove')
local MOUSEMOVE_KEY = vim.api.nvim_replace_termcodes('<MouseMove>', true, false, true)
local retire_active

--- @param surface string
--- @param target string
--- @return string
local function surface_key(surface, target, winid)
    if target == 'winbar' and winid ~= nil then
        return ('%s:%s:%d'):format(target, surface, winid)
    end
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
        local slot = #ctx._statuesque_hover_spans + 1
        local previous = ctx._statuesque_hover_previous
        local id = previous and previous.ids and previous.ids[slot] or nil
        if id == nil then
            id = M._next_id
            M._next_id = M._next_id + 1
        end
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
    if not should_collect(ctx) or end_col <= start_col then
        return 0
    end

    local slot = #ctx._statuesque_hover_spans + 1
    local previous = ctx._statuesque_hover_previous
    local id = previous and previous.ids and previous.ids[slot] or nil
    if id == nil then
        id = M._next_id
        M._next_id = M._next_id + 1
    end
    ctx._statuesque_hover_spans[#ctx._statuesque_hover_spans + 1] = {
        id = id,
        handler = handler,
        context = context or {},
        surface = ctx.surface,
        target = ctx.target,
        start_col = start_col + 1,
        end_col = end_col,
    }
    return id
end

--- Start collecting hover spans for a rendered installed surface.
--- @param ctx statuesque.RenderContext
function M.begin_render(ctx)
    if ctx._statuesque_installed_render ~= true or type(ctx.surface) ~= 'string' or type(ctx.target) ~= 'string' then
        return
    end

    ctx._statuesque_hover_collect = true
    ctx._statuesque_hover_col = 0
    ctx._statuesque_hover_spans = {}
    ctx._statuesque_hover_key = surface_key(ctx.surface, ctx.target, ctx.winid)
    ctx._statuesque_hover_previous = M._surfaces[ctx._statuesque_hover_key]
end

--- Store hover spans produced by a rendered installed surface.
--- @param ctx statuesque.RenderContext
function M.finish_render(ctx)
    if not should_collect(ctx) then
        return
    end

    local key = ctx._statuesque_hover_key
    local previous = ctx._statuesque_hover_previous
    local next_spans = ctx._statuesque_hover_spans or {}
    local active = M._active[key]
    local retained_active
    if active ~= nil then
        for _, span in ipairs(next_spans) do
            if span.id == active.id and span.start_col == active.start_col and span.end_col == active.end_col then
                retained_active = span
                break
            end
        end
        if retained_active == nil then
            retire_active(key, {
                reason = 'render',
            })
        end
    end

    local ids = vim.deepcopy(previous and previous.ids or {})
    for index, span in ipairs(next_spans) do
        ids[index] = span.id
        M._handlers[span.id] = {
            handler = span.handler,
            context = span.context,
        }
    end
    M._surfaces[key] = {
        surface = ctx.surface,
        target = ctx.target,
        winid = ctx.winid,
        ids = ids,
        spans = next_spans,
    }
    if retained_active ~= nil then
        M._active[key] = retained_active
    end
    M.refresh_mousemove_mapping()
end

--- Discard a partial render without publishing provisional handlers.
--- @param ctx statuesque.RenderContext
function M.abort_render(ctx)
    if not should_collect(ctx) then
        return
    end
    ctx._statuesque_hover_spans = {}
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

retire_active = function(key, context)
    local span = M._active[key]
    if span == nil then
        return
    end
    pcall(
        M.dispatch,
        span.id,
        'leave',
        vim.tbl_extend('force', context or {}, {
            surface = span.surface,
            target = span.target,
        })
    )
    M._active[key] = nil
end

--- @param surface string
--- @param target string
--- @param column integer
--- @return table?
local function span_at(surface, target, column, winid)
    local surface_record = M._surfaces[surface_key(surface, target, winid)]
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
            retire_active(key, context)
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
    local winid = context and tonumber(context.winid or (context.mouse and context.mouse.winid)) or nil
    local key = surface_key(surface, target, winid)
    local next_span = span_at(surface, target, column, winid)
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

local function mousemove_on_key(key)
    if key == MOUSEMOVE_KEY then
        pcall(M.handle_mousemove)
    end
end

local function has_hover_spans()
    for _, record in pairs(M._surfaces) do
        if M._installed_targets[record.target] == record.surface and #(record.spans or {}) > 0 then
            return true
        end
    end
    return false
end

local function ensure_mousemoveevent_hook()
    if M._mousemoveevent_hook_installed then
        return
    end
    M._mousemoveevent_hook_installed = true
    local group = vim.api.nvim_create_augroup('StatuesqueHoverMouseOption', { clear = true })
    vim.api.nvim_create_autocmd('OptionSet', {
        group = group,
        pattern = 'mousemoveevent',
        callback = function()
            if M._mousemove_installed and not M._changing_mousemoveevent then
                M._mousemoveevent_owned = false
            end
        end,
    })
end

local function set_mousemoveevent(value)
    M._changing_mousemoveevent = true
    vim.o.mousemoveevent = value
    M._changing_mousemoveevent = false
end

local function install_mousemove_mapping()
    if M._mousemove_installed then
        return
    end
    M._mousemove_installed = true
    M._previous_mousemoveevent = vim.o.mousemoveevent
    M._mousemoveevent_owned = true

    ensure_mousemoveevent_hook()
    set_mousemoveevent(true)
    vim.on_key(mousemove_on_key, MOUSEMOVE_NAMESPACE)
end

local function uninstall_mousemove_mapping()
    if not M._mousemove_installed then
        return
    end
    vim.on_key(nil, MOUSEMOVE_NAMESPACE)
    if M._mousemoveevent_owned and vim.o.mousemoveevent == true then
        set_mousemoveevent(M._previous_mousemoveevent == true)
    end
    M._previous_mousemoveevent = nil
    M._mousemoveevent_owned = false
    M._mousemove_installed = false
end

local function ensure_window_hooks()
    if M._window_hooks_installed then
        return
    end

    M._window_hooks_installed = true
    local group = vim.api.nvim_create_augroup('StatuesqueHoverWindows', { clear = true })
    vim.api.nvim_create_autocmd('WinClosed', {
        group = group,
        callback = function(args)
            local winid = tonumber(args.match)
            if winid ~= nil then
                M.uninstall_window(winid)
                require('statuesque.clicks').uninstall_window(winid)
            end
        end,
    })
end

function M.refresh_mousemove_mapping()
    if has_hover_spans() then
        install_mousemove_mapping()
    else
        uninstall_mousemove_mapping()
    end
end

--- Register an installed statusline-family surface for mousemove hit testing.
--- @param surface string
--- @param target 'statusline'|'tabline'|'winbar'
function M.install_surface(surface, target)
    ensure_window_hooks()
    M._installed_targets[target] = surface
    M.refresh_mousemove_mapping()
end

--- Remove hover state owned by a closed winbar window.
--- @param winid integer
function M.uninstall_window(winid)
    for key, record in pairs(M._surfaces) do
        if record.target == 'winbar' and record.winid == winid then
            retire_active(key, {
                reason = 'window',
                winid = winid,
            })
            for _, id in ipairs(record.ids or {}) do
                M._handlers[id] = nil
            end
            M._surfaces[key] = nil
        end
    end
    M.refresh_mousemove_mapping()
end

--- Remove an installed target and any hover state it owns.
--- @param target string
function M.uninstall_surface(target)
    M._installed_targets[target] = nil
    local prefix = target .. ':'
    for key, record in pairs(M._surfaces) do
        if key:sub(1, #prefix) == prefix then
            retire_active(key, {
                reason = 'uninstall',
            })
            for _, id in ipairs(record.ids or {}) do
                M._handlers[id] = nil
            end
            M._surfaces[key] = nil
        end
    end
    M.refresh_mousemove_mapping()
end

return M

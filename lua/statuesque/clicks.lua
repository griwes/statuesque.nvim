local M = {
    _next_id = 1,
    _handlers = {},
    _surfaces = {},
}

--- @param surface string
--- @param target string
--- @param winid? integer
--- @param installed? boolean
--- @return string
local function surface_key(surface, target, winid, installed)
    local prefix = installed and '' or 'preview:'
    if target == 'winbar' and winid ~= nil then
        return ('%s%s:%s:%d'):format(prefix, target, surface, winid)
    end
    return ('%s%s:%s'):format(prefix, target, surface)
end

--- @param ctx statuesque.RenderContext
--- @return boolean
local function should_collect(ctx)
    return type(ctx) == 'table' and ctx._statuesque_click_collect == true
end

--- @return string
local function ensure_global_handler()
    if _G.__statuesque_click == nil then
        _G.__statuesque_click = function(minwid, clicks, button, modifiers)
            return require('statuesque.clicks').dispatch(minwid, button, modifiers, {
                clicks = clicks,
            })
        end
    end

    return 'v:lua.__statuesque_click'
end

--- Register a clickable render node.
--- @param handler statuesque.ClickAction
--- @param context? table
--- @param render_context? statuesque.RenderContext
--- @return integer id
--- @return string function_name
function M.register(handler, context, render_context)
    if should_collect(render_context) then
        local slot = #render_context._statuesque_click_records + 1
        local previous = render_context._statuesque_click_previous
        local id = previous and previous.ids and previous.ids[slot] or nil
        if id == nil then
            id = M._next_id
            M._next_id = M._next_id + 1
        end
        render_context._statuesque_click_records[slot] = {
            id = id,
            handler = handler,
            context = context or {},
        }
        render_context._statuesque_click_ids[#render_context._statuesque_click_ids + 1] = id
        return id, ensure_global_handler()
    end

    local id = M._next_id
    M._next_id = M._next_id + 1
    M._handlers[id] = {
        handler = handler,
        context = context or {},
    }
    return id, ensure_global_handler()
end

--- Start collecting click handlers for an installed surface render.
--- @param ctx statuesque.RenderContext
function M.begin_render(ctx)
    if type(ctx.target) ~= 'string' then
        return
    end
    ctx._statuesque_click_collect = true
    ctx._statuesque_click_ids = {}
    ctx._statuesque_click_records = {}
    ctx._statuesque_click_owner = type(ctx.surface) == 'string' and ctx.surface or '__direct__'
    ctx._statuesque_click_installed = ctx._statuesque_installed_render == true
    ctx._statuesque_click_key =
        surface_key(ctx._statuesque_click_owner, ctx.target, ctx.winid, ctx._statuesque_click_installed)
    ctx._statuesque_click_previous = M._surfaces[ctx._statuesque_click_key]
end

--- @param ctx statuesque.RenderContext
--- @param start integer
--- @return table[]
function M.capture(ctx, start)
    if not should_collect(ctx) then
        return {}
    end
    local records = {}
    for index = start + 1, #ctx._statuesque_click_ids do
        local record = ctx._statuesque_click_records[index]
        if record ~= nil then
            records[#records + 1] = {
                id = record.id,
                handler = record.handler,
                context = record.context,
            }
        end
    end
    return records
end

--- Replay handlers referenced by cached Vim statusline syntax.
--- @param ctx statuesque.RenderContext
--- @param records table[]?
--- @param rendered string
--- @return string
function M.replay(ctx, records, rendered)
    if not should_collect(ctx) or type(records) ~= 'table' then
        return rendered
    end

    local replayed = {}
    for _, record in ipairs(records) do
        local id = M.register(record.handler, record.context, ctx)
        replayed[record.id] = id
    end

    return rendered:gsub('%%(%d+)@v:lua%.__statuesque_click@', function(id)
        local replayed_id = replayed[tonumber(id)]
        if replayed_id == nil then
            return nil
        end
        return ('%%%d@v:lua.__statuesque_click@'):format(replayed_id)
    end)
end

--- Replace the handler generation owned by an installed surface render.
--- @param ctx statuesque.RenderContext
function M.finish_render(ctx)
    if not should_collect(ctx) then
        return
    end
    local owner = ctx._statuesque_click_owner
    local key = ctx._statuesque_click_key
    local previous = ctx._statuesque_click_previous
    local ids = vim.deepcopy(previous and previous.ids or {})
    for index, record in ipairs(ctx._statuesque_click_records) do
        ids[index] = record.id
        M._handlers[record.id] = {
            handler = record.handler,
            context = record.context,
        }
    end
    M._surfaces[key] = {
        surface = owner,
        target = ctx.target,
        winid = ctx.winid,
        installed = ctx._statuesque_click_installed,
        ids = ids,
        active_count = #ctx._statuesque_click_records,
    }
end

--- Discard a partial render without publishing provisional handlers.
--- @param ctx statuesque.RenderContext
function M.abort_render(ctx)
    if not should_collect(ctx) then
        return
    end
    ctx._statuesque_click_records = {}
    ctx._statuesque_click_ids = {}
end

--- Drop handlers owned by an uninstalled target.
--- @param target string
function M.uninstall_target(target)
    for key, record in pairs(M._surfaces) do
        if record.target == target then
            for _, id in ipairs(record.ids or {}) do
                M._handlers[id] = nil
            end
            M._surfaces[key] = nil
        end
    end
end

--- Drop per-window handlers after a winbar owner closes.
--- @param winid integer
function M.uninstall_window(winid)
    for key, record in pairs(M._surfaces) do
        if record.target == 'winbar' and record.winid == winid then
            for _, id in ipairs(record.ids or {}) do
                M._handlers[id] = nil
            end
            M._surfaces[key] = nil
        end
    end
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

--- Dispatch a click previously registered by a renderer.
--- @param id integer|string
--- @param button? string
--- @param modifiers? string
--- @param context? table
--- @return any
function M.dispatch(id, button, modifiers, context)
    local numeric_id = tonumber(id)
    local record = numeric_id and M._handlers[numeric_id] or nil
    if record == nil then
        return nil
    end

    local payload = vim.tbl_extend('force', record.context or {}, context or {}, {
        id = numeric_id,
        button = button,
        modifiers = modifiers,
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

return M

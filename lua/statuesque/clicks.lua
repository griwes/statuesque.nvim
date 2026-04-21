local M = {
    _next_id = 1,
    _handlers = {},
}

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
--- @param handler string|function|table
--- @param context? table
--- @return integer id
--- @return string function_name
function M.register(handler, context)
    local id = M._next_id
    M._next_id = M._next_id + 1
    M._handlers[id] = {
        handler = handler,
        context = context or {},
    }

    return id, ensure_global_handler()
end

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

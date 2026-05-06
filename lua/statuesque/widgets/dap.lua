local function dap_status(dap)
    if type(dap.status) ~= 'function' then
        return nil
    end

    local ok, status = pcall(dap.status)
    if ok and type(status) == 'string' and status ~= '' then
        return status
    end
    return nil
end

local function session_name(session)
    if type(session) ~= 'table' then
        return nil
    end
    if type(session.config) == 'table' and type(session.config.name) == 'string' then
        return session.config.name
    end
    if type(session.name) == 'string' then
        return session.name
    end
    return nil
end

local function dap_session(dap)
    if type(dap.session) ~= 'function' then
        return nil
    end

    local ok, session = pcall(dap.session)
    if ok then
        return session
    end
    return nil
end

--- @param opts? statuesque.WidgetDapOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}

    return function()
        local ok, dap = pcall(require, 'dap')
        if not ok or type(dap) ~= 'table' then
            return opts.empty == true and { role = 'dap', text = opts.empty_text or '' } or false
        end

        local session = dap_session(dap)
        if session == nil and opts.show_without_session ~= true then
            return opts.empty == true and { role = 'dap', text = opts.empty_text or '' } or false
        end

        local parts = { opts.icon or '' }
        local status = dap_status(dap)
        if status ~= nil then
            parts[#parts + 1] = status
        else
            parts[#parts + 1] = opts.running_text or 'debug'
        end

        local name = session_name(session)
        if opts.session_name ~= false and name ~= nil and name ~= '' then
            parts[#parts + 1] = name
        end

        return {
            role = 'dap',
            text = table.concat(parts, ' '),
            max_width = opts.max_width or 32,
            truncate = 'right',
            hl = opts.hl or 'Debug',
        }
    end
end

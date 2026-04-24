local M = {
    _registered = {},
}

local BUILTIN = {
    debug = 'statuesque.render.debug',
    text = 'statuesque.render.text',
    vim = 'statuesque.render.vim',
    statusline = 'statuesque.render.statusline',
    tabline = 'statuesque.render.tabline',
    winbar = 'statuesque.render.winbar',
    incline = 'statuesque.render.incline',
}

function M.register(name, backend)
    assert(type(name) == 'string' and name ~= '', 'backend name must be a non-empty string')
    assert(type(backend) == 'table' and type(backend.render) == 'function', 'backend must expose render(spec, opts)')
    M._registered[name] = backend
end

function M.resolve(name)
    if M._registered[name] ~= nil then
        return M._registered[name]
    end

    local module_name = BUILTIN[name] or ('statuesque.backend.' .. name)
    local ok, backend = pcall(require, module_name)
    if not ok then
        if type(backend) == 'string' and backend:find(("module '%s' not found"):format(module_name), 1, true) then
            return nil
        end
        error(backend)
    end

    if type(backend) == 'table' and type(backend.render) == 'function' then
        M._registered[name] = backend
        return backend
    end

    return nil
end

function M.render(name, render_spec, opts)
    local backend = M.resolve(name)
    if backend == nil then
        error(('unsupported statuesque render target: %s'):format(name))
    end

    return backend.render(render_spec, opts)
end

return M

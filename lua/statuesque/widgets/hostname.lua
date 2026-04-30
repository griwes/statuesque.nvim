--- @return statuesque.RenderFunction
return function()
    return function()
        return {
            role = 'hostname',
            text = vim.loop.os_gethostname(),
        }
    end
end

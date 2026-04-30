--- @param opts? { icon?: string }
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    return function()
        local filetype = vim.bo.filetype
        if filetype == '' then
            return false
        end
        return {
            role = 'filetype',
            text = (opts.icon or '') .. filetype,
        }
    end
end

--- @param opts? statuesque.WidgetCwdOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    return function()
        return {
            role = 'cwd',
            text = vim.fn.fnamemodify(vim.fn.getcwd(), opts.path or ':~:.'),
            max_width = opts.max_width or 32,
            truncate = 'middle',
        }
    end
end

--- @param opts? statuesque.WidgetFilenameOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    return function()
        local name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
        if name == '' then
            name = '[No Name]'
        else
            name = vim.fn.fnamemodify(name, opts.path or ':t')
        end

        local flags = ''
        if vim.bo.modified then
            flags = flags .. (opts.modified_text or ' +')
        end
        if vim.bo.readonly then
            flags = flags .. (opts.readonly_text or ' RO')
        end

        return {
            role = 'filename',
            text = name .. flags,
            max_width = opts.max_width or 40,
            truncate = 'middle',
        }
    end
end

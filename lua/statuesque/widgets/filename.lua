--- @param opts? statuesque.WidgetFilenameOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    return function(context)
        local ctx = require('statuesque.context')
        local bufnr = ctx.bufnr(context)
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name == '' then
            name = '[No Name]'
        else
            name = vim.fn.fnamemodify(name, opts.path or ':t')
        end

        local flags = ''
        if ctx.buffer_option(context, 'modified') then
            flags = flags .. (opts.modified_text or ' +')
        end
        if ctx.buffer_option(context, 'readonly') then
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

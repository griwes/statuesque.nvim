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
        elseif opts.path == nil or opts.path == ':t' then
            name = vim.fs.basename(name)
        else
            name = vim.fn.fnamemodify(name, opts.path or ':t')
        end

        local modified = ctx.buffer_option(context, 'modified')
        local readonly = ctx.buffer_option(context, 'readonly')
        local filename = {
            role = 'filename',
            text = name,
            max_width = opts.max_width or 40,
            truncate = 'middle',
        }
        if modified and opts.modified_hl ~= nil then
            filename.hl = opts.modified_hl
        end

        if opts.separate_flags == true then
            local children = { filename }
            if modified then
                children[#children + 1] = {
                    role = 'filename-modified',
                    text = opts.modified_text or ' +',
                }
            end
            if readonly then
                children[#children + 1] = {
                    role = 'filename-readonly',
                    text = opts.readonly_text or ' RO',
                }
            end
            return children
        end

        if modified then
            filename.text = filename.text .. (opts.modified_text or ' +')
        end
        if readonly then
            filename.text = filename.text .. (opts.readonly_text or ' RO')
        end
        return filename
    end
end

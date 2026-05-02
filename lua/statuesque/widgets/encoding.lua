--- @return statuesque.RenderFunction
return function()
    return function(context)
        local ctx = require('statuesque.context')
        local fileencoding = ctx.buffer_option(context, 'fileencoding')
        return {
            role = 'encoding',
            text = table.concat(
                { fileencoding ~= '' and fileencoding or vim.o.encoding, ctx.buffer_option(context, 'fileformat') },
                ' '
            ),
        }
    end
end

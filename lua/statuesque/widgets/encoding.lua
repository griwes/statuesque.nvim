--- @return statuesque.RenderFunction
return function()
    return function()
        return {
            role = 'encoding',
            text = table.concat(
                { vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding, vim.bo.fileformat },
                ' '
            ),
        }
    end
end

--- @return statuesque.RenderFunction
return function()
    return function()
        local current = vim.fn.line('.')
        local total = math.max(1, vim.fn.line('$'))
        local label
        if current == 1 then
            label = 'Top'
        elseif current == total then
            label = 'Bot'
        else
            label = math.floor(current * 100 / total) .. '%'
        end

        return {
            role = 'progress',
            text = label,
        }
    end
end

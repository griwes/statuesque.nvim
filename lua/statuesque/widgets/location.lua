--- @return statuesque.RenderFunction
return function()
    return function(context)
        local cursor = require('statuesque.context').window_cursor(context)
        return {
            role = 'location',
            text = ('%d:%d'):format(cursor[1], cursor[2] + 1),
        }
    end
end

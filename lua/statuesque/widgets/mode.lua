local publisher = require('statuesque.publisher')
local style = require('statuesque.style')

local MODE_LABELS = {
    normal = 'NORMAL',
    insert = 'INSERT',
    visual = 'VISUAL',
    replace = 'REPLACE',
    command = 'COMMAND',
    terminal = 'TERM',
}

--- @param opts? statuesque.WidgetModeOptions
--- @return statuesque.PublisherComponent
return function(opts)
    opts = opts or {}
    return publisher.new(function()
        local mode_name = style.mode_name()
        local label = MODE_LABELS[mode_name] or mode_name:upper()
        if opts.icon then
            label = opts.icon .. ' ' .. label
        end

        return {
            text = label,
            role = 'mode',
            hl = style.mode_style(mode_name),
        }
    end, function(_, notify)
        local group = vim.api.nvim_create_augroup('statuesque-mode-widget', { clear = false })
        vim.api.nvim_create_autocmd({ 'ModeChanged', 'RecordingEnter', 'RecordingLeave' }, {
            group = group,
            callback = notify,
        })
    end)
end

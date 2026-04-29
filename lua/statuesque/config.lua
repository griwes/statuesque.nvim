--- @type statuesque.Config
local default_config = {
    style = 'slanted',
    publish = {
        auto = {
            statusline = true,
        },
    },
    targets = {},
}

local M = {}

--- @type statuesque.Config
M.config = default_config
local style_watchers = {}

local function notify_style_watchers(style)
    for _, watcher in ipairs(vim.deepcopy(style_watchers)) do
        pcall(watcher, style)
    end
end

--- Replace current configuration with the default config extended by `config`.
--- @param config? statuesque.Config Configuration to extend the default config with.
function M.configure(config)
    local previous_style = M.style()
    M.config = vim.tbl_deep_extend('force', default_config, config or {})
    local next_style = M.style()
    if next_style ~= previous_style then
        notify_style_watchers(next_style)
    end
end

--- @return string
function M.style()
    return M.config.style or 'slanted'
end

--- @param callback fun(style: string)
--- @return fun()
function M.on_style_change(callback)
    assert(type(callback) == 'function', 'style change callback must be a function')
    style_watchers[#style_watchers + 1] = callback
    local index = #style_watchers
    return function()
        style_watchers[index] = function() end
    end
end

return M

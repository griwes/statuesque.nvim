--- @type statuesque.Config
local default_config = {
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

--- Replace current configuration with the default config extended by `config`.
--- @param config? statuesque.Config Configuration to extend the default config with.
function M.configure(config)
    M.config = vim.tbl_deep_extend('force', default_config, config or {})
end

return M

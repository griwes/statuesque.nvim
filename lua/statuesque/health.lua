local M = {}

local function check_optional(module, label)
    if pcall(require, module) then
        vim.health.ok(label .. ' integration is available')
    else
        vim.health.info(label .. ' integration is not installed')
    end
end

function M.check()
    vim.health.start('statuesque.nvim')

    if vim.fn.has('nvim-0.11') == 1 then
        vim.health.ok('Neovim 0.11 or newer')
    else
        vim.health.error('Neovim 0.11 or newer is required')
    end

    for _, target in ipairs({ 'text', 'debug', 'statusline', 'tabline', 'winbar', 'incline' }) do
        local ok, capabilities = pcall(require('statuesque').backend_capabilities, target)
        if ok and type(capabilities) == 'table' then
            vim.health.ok('Backend is available: ' .. target)
        else
            vim.health.error('Backend failed to load: ' .. target)
        end
    end

    check_optional('tabulature', 'Tabulature')
    check_optional('incline', 'Incline')
    check_optional('manifold', 'Manifold')
end

return M

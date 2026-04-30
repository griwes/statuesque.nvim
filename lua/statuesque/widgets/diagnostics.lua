--- @param opts? statuesque.WidgetDiagnosticsOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    local labels = opts.labels
        or {
            [vim.diagnostic.severity.ERROR] = 'E',
            [vim.diagnostic.severity.WARN] = 'W',
            [vim.diagnostic.severity.INFO] = 'I',
            [vim.diagnostic.severity.HINT] = 'H',
        }

    return function()
        local counts = vim.diagnostic.count(vim.api.nvim_get_current_buf())
        local parts = {}

        for _, severity in ipairs({
            vim.diagnostic.severity.ERROR,
            vim.diagnostic.severity.WARN,
            vim.diagnostic.severity.INFO,
            vim.diagnostic.severity.HINT,
        }) do
            if (counts[severity] or 0) > 0 then
                parts[#parts + 1] = labels[severity] .. counts[severity]
            end
        end

        if #parts == 0 then
            return opts.empty == false and false or { text = opts.empty_text or 'OK', role = 'diagnostics' }
        end

        return {
            text = table.concat(parts, ' '),
            role = 'diagnostics',
            hl = counts[vim.diagnostic.severity.ERROR] and 'StatuesqueError' or 'StatuesqueWarning',
        }
    end
end

--- @param opts? statuesque.WidgetDiagnosticsOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}

    return function(context)
        local labels = opts.labels
            or {
                [vim.diagnostic.severity.ERROR] = 'E',
                [vim.diagnostic.severity.WARN] = 'W',
                [vim.diagnostic.severity.INFO] = 'I',
                [vim.diagnostic.severity.HINT] = 'H',
            }
        if opts.signs == true then
            local signs = vim.diagnostic.config().signs
            labels = type(signs) == 'table' and type(signs.text) == 'table' and signs.text or labels
        end

        local counts = vim.diagnostic.count(require('statuesque.context').bufnr(context))
        local parts = {}
        local children = {}

        for _, severity in ipairs({
            vim.diagnostic.severity.ERROR,
            vim.diagnostic.severity.WARN,
            vim.diagnostic.severity.INFO,
            vim.diagnostic.severity.HINT,
        }) do
            if (counts[severity] or 0) > 0 then
                local label = labels[severity] or ''
                local text = label .. counts[severity]
                parts[#parts + 1] = text
                children[#children + 1] = {
                    text = text,
                    hl = ({
                        [vim.diagnostic.severity.ERROR] = 'DiagnosticSignError',
                        [vim.diagnostic.severity.WARN] = 'DiagnosticSignWarn',
                        [vim.diagnostic.severity.INFO] = 'DiagnosticSignInfo',
                        [vim.diagnostic.severity.HINT] = 'DiagnosticSignHint',
                    })[severity],
                }
                children[#children + 1] = { text = ' ' }
            end
        end

        if #parts == 0 then
            return opts.empty == false and false or { text = opts.empty_text or 'OK', role = 'diagnostics' }
        end
        if children[#children] ~= nil and children[#children].text == ' ' then
            children[#children] = nil
        end
        if opts.signs == true then
            return {
                role = 'diagnostics',
                children = children,
            }
        end

        return {
            text = table.concat(parts, ' '),
            role = 'diagnostics',
            hl = counts[vim.diagnostic.severity.ERROR] and 'StatuesqueError' or 'StatuesqueWarning',
        }
    end
end

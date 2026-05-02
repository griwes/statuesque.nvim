--- @param value any
--- @return string?
local function text_from_part(value)
    if type(value) == 'string' then
        return value
    end
    if type(value) ~= 'table' then
        return nil
    end
    if type(value.text) == 'string' then
        return value.text
    end
    if type(value.name) == 'string' then
        return value.name
    end
    return nil
end

--- @param value any
--- @param separator string
--- @return string?
local function coerce_text(value, separator)
    if type(value) == 'string' then
        return value
    end
    if type(value) ~= 'table' then
        return nil
    end
    if type(value.text) == 'string' then
        return value.text
    end

    local parts = {}
    for index = 1, #value do
        local part = text_from_part(value[index])
        if part ~= nil and part ~= '' then
            parts[#parts + 1] = part
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, separator)
end

--- @param context? statuesque.RenderContext
--- @return integer
local function context_bufnr(context)
    local bufnr = context and tonumber(context.bufnr or context.buf or context.buffer)
    if bufnr ~= nil and bufnr > 0 then
        return math.floor(bufnr)
    end
    return vim.api.nvim_get_current_buf()
end

local navic_autocmd_created = false
local attached_navic_clients = {}

--- @param client table?
--- @return boolean
local function client_supports_document_symbols(client)
    return type(client) == 'table'
        and type(client.server_capabilities) == 'table'
        and client.server_capabilities.documentSymbolProvider ~= nil
        and client.server_capabilities.documentSymbolProvider ~= false
end

--- @param client table
--- @param bufnr integer
--- @return string
local function navic_attach_key(client, bufnr)
    return ('%d:%s'):format(bufnr, tostring(client.id or client.name or client))
end

--- @param navic table
--- @param client table?
--- @param bufnr integer
local function attach_navic_to_client(navic, client, bufnr)
    if type(navic.attach) ~= 'function' or not client_supports_document_symbols(client) then
        return
    end

    local key = navic_attach_key(client, bufnr)
    if attached_navic_clients[key] then
        return
    end

    local ok = pcall(navic.attach, client, bufnr)
    if ok then
        attached_navic_clients[key] = true
    end
end

--- @param opts statuesque.WidgetBreadcrumbsOptions
local function ensure_navic_autocmd(opts)
    if opts.navic == false or opts.auto_attach == false or navic_autocmd_created then
        return
    end

    navic_autocmd_created = true
    local group = vim.api.nvim_create_augroup('StatuesqueBreadcrumbsNavic', { clear = true })
    vim.api.nvim_create_autocmd('LspAttach', {
        group = group,
        callback = function(args)
            local ok, navic = pcall(require, 'nvim-navic')
            if not ok then
                return
            end

            local client_id = args.data and args.data.client_id
            local client = nil
            if client_id ~= nil and type(vim.lsp) == 'table' and type(vim.lsp.get_client_by_id) == 'function' then
                client = vim.lsp.get_client_by_id(client_id)
            end
            attach_navic_to_client(navic, client, args.buf)
        end,
    })
end

--- @param opts statuesque.WidgetBreadcrumbsOptions
--- @param navic table
--- @param bufnr integer
local function attach_existing_navic_clients(opts, navic, bufnr)
    if opts.navic == false or opts.auto_attach == false then
        return
    end
    if type(vim.lsp) ~= 'table' or type(vim.lsp.get_clients) ~= 'function' then
        return
    end

    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        attach_navic_to_client(navic, client, bufnr)
    end
end

--- @param opts statuesque.WidgetBreadcrumbsOptions
--- @param context? statuesque.RenderContext
--- @return statuesque.RenderSpec
local function navic_breadcrumbs(opts, context)
    if opts.navic == false then
        return false
    end

    local navic = require('nvim-navic')

    local bufnr = context_bufnr(context)
    attach_existing_navic_clients(opts, navic, bufnr)

    if type(navic.is_available) == 'function' and not navic.is_available(bufnr) then
        return false
    end
    if type(navic.get_location) ~= 'function' then
        return false
    end

    local location = navic.get_location({
        separator = opts.separator or ' > ',
        highlight = false,
        depth_limit = opts.depth_limit,
        depth_limit_indicator = opts.depth_limit_indicator,
    })
    if type(location) ~= 'string' or location == '' then
        return false
    end
    return location
end

--- @param opts? statuesque.WidgetBreadcrumbsOptions
--- @return statuesque.RenderFunction
return function(opts)
    opts = opts or {}
    ensure_navic_autocmd(opts)

    return function(context)
        local value = false
        if type(opts.provider) == 'function' then
            value = opts.provider(context)
        end
        if value == false or value == nil then
            local bufnr = context_bufnr(context)
            value = vim.b[bufnr].statuesque_breadcrumbs
        end
        if value == false or value == nil then
            value = navic_breadcrumbs(opts, context)
        end

        local text = coerce_text(value, opts.separator or ' > ')
        if text == nil or text == '' then
            if opts.empty == true then
                text = opts.empty_text or ''
            else
                return false
            end
        end

        return {
            role = 'breadcrumbs',
            text = text,
            max_width = opts.max_width or 80,
            truncate = opts.truncate or 'left',
        }
    end
end

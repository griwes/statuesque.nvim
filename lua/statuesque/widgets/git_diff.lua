--- @class statuesque.WidgetGitDiffStatus
--- @field added? integer
--- @field changed? integer
--- @field removed? integer

--- @param context? table
--- @return string?
local function buffer_path(context)
    local bufnr = context and (context.bufnr or context.buf or context.buffer)
    if type(bufnr) ~= 'number' or not vim.api.nvim_buf_is_valid(bufnr) then
        return nil
    end

    local path = vim.api.nvim_buf_get_name(bufnr)
    if path == '' then
        return nil
    end

    return path
end

--- @param context? table
--- @return statuesque.WidgetGitDiffStatus?
local function stratum_status(context)
    local path = buffer_path(context)
    if path == nil then
        return nil
    end

    local ok, stratum = pcall(require, 'stratum')
    if not ok or type(stratum.path_summary) ~= 'function' then
        return nil
    end

    local success, summary = pcall(stratum.path_summary, path)
    if not success or type(summary) ~= 'table' then
        return nil
    end

    return {
        added = summary.added,
        changed = summary.changed,
        removed = summary.removed,
    }
end

--- @param context? table
--- @return statuesque.WidgetGitDiffStatus?
local function buffer_var_status(context)
    local ctx = require('statuesque.context')
    return ctx.buffer_var(context, 'vgit_status') or ctx.buffer_var(context, 'gitsigns_status_dict')
end

--- @param opts? statuesque.WidgetGitDiffOptions
--- @return statuesque.PublisherComponent
return function(opts)
    opts = opts or {}
    local labels = opts.labels or {
        added = ' ',
        changed = ' ',
        removed = ' ',
    }
    local highlights = opts.highlights
        or {
            added = 'DiffAdd',
            changed = 'DiffChange',
            removed = 'DiffDelete',
        }

    local function render(_, context)
        local status = stratum_status(context) or buffer_var_status(context)
        if type(status) ~= 'table' then
            return false
        end

        local children = {}
        for _, key in ipairs({ 'added', 'changed', 'removed' }) do
            local count = tonumber(status[key]) or 0
            if count > 0 then
                children[#children + 1] = {
                    text = labels[key] .. count,
                    hl = highlights[key],
                }
                children[#children + 1] = { text = ' ' }
            end
        end

        if children[#children] ~= nil and children[#children].text == ' ' then
            children[#children] = nil
        end
        if #children == 0 then
            return opts.empty == true and { role = 'git-diff', text = opts.empty_text or '' } or false
        end

        return {
            role = 'git-diff',
            children = children,
        }
    end

    local function subscribe(_, notify)
        local group = vim.api.nvim_create_augroup('statuesque-git-diff-widget', { clear = false })
        local buffer_autocmd = vim.api.nvim_create_autocmd(
            { 'BufEnter', 'BufFilePost', 'BufWritePost', 'DirChanged' },
            {
                group = group,
                callback = notify,
            }
        )
        local stratum_autocmd = vim.api.nvim_create_autocmd('User', {
            group = group,
            pattern = 'StratumRepositoryUpdated',
            callback = notify,
        })

        return function()
            pcall(vim.api.nvim_del_autocmd, buffer_autocmd)
            pcall(vim.api.nvim_del_autocmd, stratum_autocmd)
        end
    end

    return require('statuesque.publisher').new(render, subscribe)
end

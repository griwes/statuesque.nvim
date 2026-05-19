--- @class statuesque.WidgetGitDiffStatus
--- @field added? integer
--- @field changed? integer
--- @field removed? integer

--- @class statuesque.WidgetGitDiffSource
--- @field var string Buffer variable to inspect.
--- @field path? string|string[] Optional nested table path inside the buffer variable.
--- @field keys? table<string, string|integer|string[]|integer[]> Field mapping for added/changed/removed counts.

local DEFAULT_BUFFER_SOURCES = {
    { var = 'vgit_status' },
    { var = 'gitsigns_status_dict' },
    { var = 'minidiff_summary', keys = { added = 'add', changed = 'change', removed = 'delete' } },
    { var = 'gitgutter_summary', keys = { added = 1, changed = 2, removed = 3 } },
    { var = 'gitgutter', path = 'summary', keys = { added = 1, changed = 2, removed = 3 } },
}

local DEFAULT_KEYS = {
    added = { 'added', 'add', 'inserted', 'insertions', 1 },
    changed = { 'changed', 'change', 'modified', 'modified_lines', 2 },
    removed = { 'removed', 'delete', 'deleted', 'deletions', 3 },
}

--- @param value any
--- @return number?
local function number(value)
    value = tonumber(value)
    if value == nil then
        return nil
    end
    return value
end

--- @param value table?
--- @param path? string|integer|(string|integer)[]
--- @return any
local function get_path(value, path)
    if type(value) ~= 'table' or path == nil then
        return value
    end
    if type(path) ~= 'table' then
        return value[path]
    end
    local current = value
    for _, part in ipairs(path) do
        if type(current) ~= 'table' then
            return nil
        end
        current = current[part]
    end
    return current
end

--- @param value table
--- @param keys string|integer|(string|integer)[]|nil
--- @return number?
local function count_from_keys(value, keys)
    if type(value) ~= 'table' or keys == nil then
        return nil
    end
    if type(keys) ~= 'table' then
        return number(value[keys])
    end
    for _, key in ipairs(keys) do
        local count = number(value[key])
        if count ~= nil then
            return count
        end
    end
    return nil
end

--- @param value table?
--- @param source? statuesque.WidgetGitDiffSource
--- @return statuesque.WidgetGitDiffStatus?
local function normalize_status(value, source)
    if type(value) ~= 'table' then
        return nil
    end
    local candidate = get_path(value, source and source.path)
    if type(candidate) ~= 'table' then
        return nil
    end

    local keys = source and source.keys or {}
    local status = {
        added = count_from_keys(candidate, keys.added) or count_from_keys(candidate, DEFAULT_KEYS.added),
        changed = count_from_keys(candidate, keys.changed) or count_from_keys(candidate, DEFAULT_KEYS.changed),
        removed = count_from_keys(candidate, keys.removed) or count_from_keys(candidate, DEFAULT_KEYS.removed),
    }
    if status.added == nil and status.changed == nil and status.removed == nil then
        return nil
    end
    return status
end

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
--- @param opts? statuesque.WidgetGitDiffOptions
--- @return statuesque.WidgetGitDiffStatus?
local function stratum_status(context, opts)
    if opts and opts.stratum == false then
        return nil
    end
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

    return normalize_status({
        added = summary.added,
        changed = summary.changed,
        removed = summary.removed,
    })
end

--- @param source string|statuesque.WidgetGitDiffSource
--- @return statuesque.WidgetGitDiffSource?
local function normalize_source(source)
    if type(source) == 'string' then
        return { var = source }
    end
    if type(source) == 'table' and type(source.var) == 'string' then
        return source
    end
    return nil
end

--- @param context? table
--- @param opts? statuesque.WidgetGitDiffOptions
--- @return statuesque.WidgetGitDiffStatus?
local function buffer_var_status(context, opts)
    local ctx = require('statuesque.context')
    local sources = opts and opts.sources or DEFAULT_BUFFER_SOURCES
    for _, raw_source in ipairs(sources) do
        local source = normalize_source(raw_source)
        if source ~= nil then
            local status = normalize_status(ctx.buffer_var(context, source.var), source)
            if status ~= nil then
                return status
            end
        end
    end
    return nil
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
        local status = stratum_status(context, opts) or buffer_var_status(context, opts)
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

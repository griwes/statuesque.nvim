local M = {}

local WINDOW_SCOPED_TARGETS = {
    incline = true,
    winbar = true,
}

--- @param value any
--- @return integer?
local function positive_integer(value)
    value = tonumber(value)
    if value == nil or value <= 0 then
        return nil
    end
    return math.floor(value)
end

--- @param winid integer?
--- @return boolean
local function valid_window(winid)
    return winid ~= nil and vim.api.nvim_win_is_valid(winid)
end

--- @param target? statuesque.Target
--- @return statuesque.RenderScope
function M.scope_for_target(target)
    if WINDOW_SCOPED_TARGETS[target] then
        return 'window'
    end
    return 'global'
end

--- @param target? statuesque.Target
--- @param opts? statuesque.RenderContext
--- @return integer?
local function infer_winid(target, opts)
    local winid = positive_integer(opts and (opts.winid or opts.win_id or opts.window))
    if winid ~= nil then
        return winid
    end

    if target == 'winbar' then
        winid = positive_integer(vim.g.statusline_winid)
        if winid ~= nil then
            return winid
        end
    end

    if target ~= nil and WINDOW_SCOPED_TARGETS[target] then
        return vim.api.nvim_get_current_win()
    end

    return nil
end

--- @param winid integer?
--- @param opts? statuesque.RenderContext
--- @return integer?
local function infer_bufnr(winid, opts)
    local bufnr = positive_integer(opts and (opts.bufnr or opts.buf or opts.buffer))
    if bufnr ~= nil then
        return bufnr
    end

    if valid_window(winid) then
        return vim.api.nvim_win_get_buf(winid)
    end

    return nil
end

--- @param winid integer?
--- @return integer?
local function infer_winnr(winid)
    if not valid_window(winid) then
        return nil
    end

    local winnr = vim.api.nvim_win_get_number(winid)
    return positive_integer(winnr)
end

--- Add target, scope, window, and buffer fields expected by per-window backends.
--- @param opts? statuesque.RenderContext
--- @param target statuesque.Target
--- @return statuesque.RenderContext
function M.with_target(opts, target)
    local ctx = vim.tbl_extend('force', opts or {}, {
        target = target,
    })
    ctx.render_scope = ctx.render_scope or M.scope_for_target(target)

    if ctx.render_scope == 'window' then
        ctx.winid = infer_winid(target, ctx)
        ctx.bufnr = infer_bufnr(ctx.winid, ctx)
        ctx.winnr = positive_integer(ctx.winnr) or infer_winnr(ctx.winid)
    elseif ctx.render_scope == 'buffer' then
        ctx.bufnr = infer_bufnr(nil, ctx)
    end

    return ctx
end

--- @param cache_opts? statuesque.CacheConfig
--- @param opts? statuesque.RenderContext
--- @return statuesque.RenderScope
function M.cache_scope(cache_opts, opts)
    if type(cache_opts) == 'table' and cache_opts.cache_mode ~= nil then
        return cache_opts.cache_mode
    end
    if opts and opts.cache_scope ~= nil then
        return opts.cache_scope
    end
    if opts and opts.render_scope ~= nil then
        return opts.render_scope
    end
    return M.scope_for_target(opts and opts.target or nil)
end

--- @param opts? statuesque.RenderContext
--- @param cache_opts? statuesque.CacheConfig
--- @return string?
function M.cache_variant(opts, cache_opts)
    local scope = M.cache_scope(cache_opts, opts)
    if scope == 'global' then
        return nil
    end

    if scope == 'window' then
        return ('window:%s:buffer:%s'):format(tostring(opts and opts.winid or ''), tostring(opts and opts.bufnr or ''))
    end

    if scope == 'buffer' then
        return ('buffer:%s'):format(tostring(opts and opts.bufnr or ''))
    end

    return tostring(scope)
end

return M

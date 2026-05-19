local M = {}

local STATE_VAR = 'statuesque_window_surface_replacements'
local autocmds_registered = false

---@param target string
local function assert_target(target)
    assert(type(target) == 'string' and target:match('^[%w_]+$') ~= nil, 'target must be an option name')
end

---@param winid integer
---@return table<string, { owner: string, bufnr: integer }>
local function replacement_state(winid)
    local state = vim.w[winid][STATE_VAR]

    if type(state) ~= 'table' then
        state = {}
        vim.w[winid][STATE_VAR] = state
    end

    return state
end

---@param winid integer
---@param target string
local function reset_window_target(winid, target)
    assert_target(target)

    if not vim.api.nvim_win_is_valid(winid) then
        return
    end

    pcall(vim.api.nvim_win_call, winid, function()
        vim.cmd(('setlocal %s<'):format(target))
    end)
end

---@param winid integer
---@param target string
local function clear_replacement(winid, target)
    if not vim.api.nvim_win_is_valid(winid) then
        return
    end

    local state = replacement_state(winid)

    if state[target] == nil then
        return
    end

    state[target] = nil
    reset_window_target(winid, target)

    if next(state) == nil then
        vim.w[winid][STATE_VAR] = nil
    end
end

---@param winid integer
local function clear_stale_replacements(winid)
    if not vim.api.nvim_win_is_valid(winid) then
        return
    end

    local state = vim.w[winid][STATE_VAR]

    if type(state) ~= 'table' then
        return
    end

    local current_bufnr = vim.api.nvim_win_get_buf(winid)
    local stale_targets = {}

    for target, replacement in pairs(state) do
        if type(replacement) ~= 'table' or replacement.bufnr ~= current_bufnr then
            stale_targets[#stale_targets + 1] = target
        end
    end

    for _, target in ipairs(stale_targets) do
        clear_replacement(winid, target)
    end
end

local function ensure_autocmds()
    if autocmds_registered then
        return
    end

    local group = vim.api.nvim_create_augroup('statuesque-window-surface', {
        clear = true,
    })

    vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
        group = group,
        desc = 'Restore window-local surfaces after owner buffers leave windows',
        callback = function()
            clear_stale_replacements(vim.api.nvim_get_current_win())
        end,
    })

    autocmds_registered = true
end

---@param bufnr integer
---@return integer[]
local function target_windows(bufnr)
    local matches = {}

    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
            matches[#matches + 1] = winid
        end
    end

    return matches
end

---@class statuesque.WindowSurfaceReplacement
---@field owner string
---@field target string
---@field winid? integer
---@field bufnr integer
---@field expression string
---@field all_windows? boolean

---@param opts table
local function assert_replacement_opts(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.owner) == 'string' and opts.owner ~= '', 'owner must be a non-empty string')
    assert(type(opts.bufnr) == 'number' and vim.api.nvim_buf_is_valid(opts.bufnr), 'bufnr must be a valid buffer')
    assert(type(opts.expression) == 'string', 'expression must be a string')
    assert(opts.winid == nil or type(opts.winid) == 'number', 'winid must be a number when provided')
    assert(
        opts.all_windows == nil or type(opts.all_windows) == 'boolean',
        'all_windows must be a boolean when provided'
    )
    assert(not (opts.winid ~= nil and opts.all_windows == true), 'winid and all_windows are mutually exclusive')
    if opts.all_windows ~= true then
        assert(opts.winid ~= nil and vim.api.nvim_win_is_valid(opts.winid), 'winid must be a valid window')
    end
    assert_target(opts.target)
end

---@param opts statuesque.WindowSurfaceReplacement
---@return integer[]
local function replacement_windows(opts)
    if opts.all_windows == true then
        return target_windows(opts.bufnr)
    end

    return { opts.winid }
end

---Replace a window-local render target while the selected window(s) display a buffer.
---@param opts statuesque.WindowSurfaceReplacement
---@return integer[] windows Updated windows.
function M.replace(opts)
    assert_replacement_opts(opts)
    ensure_autocmds()

    local updated = {}

    for _, winid in ipairs(replacement_windows(opts)) do
        if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == opts.bufnr then
            vim.api.nvim_set_option_value(opts.target, opts.expression, {
                win = winid,
            })
            replacement_state(winid)[opts.target] = {
                owner = opts.owner,
                bufnr = opts.bufnr,
            }
            updated[#updated + 1] = winid
        end
    end

    return updated
end

---@param winid integer
---@param target string
function M.clear(winid, target)
    clear_replacement(winid, target)
end

return M

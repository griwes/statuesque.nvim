local publisher = require('statuesque.publisher')
local style = require('statuesque.style')

local M = {}

local MODE_LABELS = {
    normal = 'NORMAL',
    insert = 'INSERT',
    visual = 'VISUAL',
    replace = 'REPLACE',
    command = 'COMMAND',
    terminal = 'TERM',
}

local function current_buf()
    return vim.api.nvim_get_current_buf()
end

local function current_win()
    return vim.api.nvim_get_current_win()
end

function M.mode(opts)
    opts = opts or {}
    return publisher.new(function()
        local mode_name = style.mode_name()
        return {
            text = opts.icon and (opts.icon .. ' ' .. (MODE_LABELS[mode_name] or mode_name:upper()))
                or (MODE_LABELS[mode_name] or mode_name:upper()),
            role = 'mode',
            hl = style.mode_style(mode_name),
        }
    end, function(_, notify)
        local group = vim.api.nvim_create_augroup('statuesque-mode-widget', { clear = false })
        vim.api.nvim_create_autocmd({ 'ModeChanged', 'RecordingEnter', 'RecordingLeave' }, {
            group = group,
            callback = notify,
        })
    end, {
        cache = { key = opts.cache_key or 'statuesque.widget.mode' },
    })
end

function M.filename(opts)
    opts = opts or {}
    return function()
        local name = vim.api.nvim_buf_get_name(current_buf())
        if name == '' then
            name = '[No Name]'
        else
            name = vim.fn.fnamemodify(name, opts.path or ':t')
        end

        local flags = ''
        if vim.bo.modified then
            flags = flags .. (opts.modified_text or ' +')
        end
        if vim.bo.readonly then
            flags = flags .. (opts.readonly_text or ' RO')
        end

        return {
            role = 'filename',
            text = name .. flags,
            max_width = opts.max_width or 40,
            truncate = 'middle',
        }
    end
end

function M.diagnostics(opts)
    opts = opts or {}
    local labels = opts.labels
        or {
            [vim.diagnostic.severity.ERROR] = 'E',
            [vim.diagnostic.severity.WARN] = 'W',
            [vim.diagnostic.severity.INFO] = 'I',
            [vim.diagnostic.severity.HINT] = 'H',
        }

    return function()
        local counts = vim.diagnostic.count(current_buf())
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

function M.git_branch(opts)
    opts = opts or {}
    return function()
        local head = vim.b.gitsigns_head or vim.b.minidiff_summary_string
        if type(head) ~= 'string' or head == '' then
            return false
        end

        return {
            role = 'git-branch',
            text = (opts.icon or '') .. ' ' .. head,
            max_width = opts.max_width or 24,
            truncate = 'right',
        }
    end
end

function M.filetype(opts)
    opts = opts or {}
    return function()
        local filetype = vim.bo.filetype
        if filetype == '' then
            return false
        end
        return {
            role = 'filetype',
            text = (opts.icon or '') .. filetype,
        }
    end
end

function M.encoding()
    return function()
        return {
            role = 'encoding',
            text = table.concat(
                { vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding, vim.bo.fileformat },
                ' '
            ),
        }
    end
end

function M.location()
    return function()
        local cursor = vim.api.nvim_win_get_cursor(current_win())
        return {
            role = 'location',
            text = ('%d:%d'):format(cursor[1], cursor[2] + 1),
        }
    end
end

function M.progress()
    return function()
        local current = vim.fn.line('.')
        local total = math.max(1, vim.fn.line('$'))
        local label = current == 1 and 'Top'
            or current == total and 'Bot'
            or (math.floor(current * 100 / total) .. '%%')

        return {
            role = 'progress',
            text = label,
        }
    end
end

function M.cwd(opts)
    opts = opts or {}
    return function()
        return {
            role = 'cwd',
            text = vim.fn.fnamemodify(vim.fn.getcwd(), opts.path or ':~:.'),
            max_width = opts.max_width or 32,
            truncate = 'middle',
        }
    end
end

function M.hostname()
    return function()
        return {
            role = 'hostname',
            text = vim.loop.os_gethostname(),
        }
    end
end

function M.static(value, opts)
    opts = opts or {}
    return {
        role = opts.role or 'static',
        text = value,
        hl = opts.hl,
    }
end

function M.tabulature(opts)
    opts = opts or {}
    return function()
        local ok, tabulature = pcall(require, 'tabulature')
        if not ok or type(tabulature) ~= 'table' or type(tabulature.api) ~= 'table' then
            return false
        end

        local render_ok, renderer = pcall(require, 'tabulature.render.statuesque')
        if not render_ok or type(renderer.to_spec) ~= 'function' then
            return false
        end

        local root = type(tabulature.api.tree) == 'function' and tabulature.api.tree() or nil
        if root == nil then
            return false
        end

        return renderer.to_spec(root, opts)
    end
end

return M

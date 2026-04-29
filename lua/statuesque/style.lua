local spec = require('statuesque.spec')

local M = {}

local DEFAULT_MIN_CONTRAST = 4.5
local DEFAULT_INNER_MIX = 0.85
local DEFAULT_READABLE_DARK = '#1a1b26'
local DEFAULT_READABLE_LIGHT = '#c0caf5'
local HARD_READABLE_DARK = '#000000'
local HARD_READABLE_LIGHT = '#ffffff'
--- @type statuesque.HighlightSpec
local DEFAULT_SIGIL_HL = { fg = '#1a1b26', bg = '#ff9e64', bold = true }

--- @type table<statuesque.Surface, statuesque.BackendDefaults>
local DEFAULTS = {
    statusline = {
        sigil = '',
        sigil_hl = DEFAULT_SIGIL_HL,
        left_separator = '',
        right_separator = '',
        inner_left_separator = '',
        inner_right_separator = '',
        separator_padding = ' ',
        sigil_leading_padding = ' ',
        gap_padding = '',
        base = { fg = '#565f89', bg = '#1f2335' },
        outer = { fg = '#1a1b26', bg = '#7aa2f7', bold = true },
        inner = { fg = '#c0caf5', bg = '#3b4261' },
    },
    tabline = {
        sigil = '',
        tabulature_sigil = '𝄞',
        sigil_hl = DEFAULT_SIGIL_HL,
        left_separator = '',
        right_separator = '',
        inner_left_separator = '',
        inner_right_separator = '',
        separator_padding = ' ',
        sigil_leading_padding = ' ',
        gap_padding = '',
        base = { fg = '#565f89', bg = '#1f2335' },
        outer = { fg = '#1a1b26', bg = '#bb9af7', bold = true },
        inner = { fg = '#c0caf5', bg = '#292e42' },
    },
    winbar = {
        sigil = '',
        sigil_hl = DEFAULT_SIGIL_HL,
        left_separator = '',
        right_separator = '',
        inner_left_separator = '',
        inner_right_separator = '',
        separator_padding = ' ',
        sigil_leading_padding = ' ',
        gap_padding = '',
        base = { fg = '#565f89', bg = '#1f2335' },
        outer = { fg = '#7dcfff', bg = '#24283b', bold = true },
        inner = { fg = '#a9b1d6', bg = '#1f2335' },
    },
    incline = {
        sigil = '',
        sigil_hl = DEFAULT_SIGIL_HL,
        left_separator = '',
        right_separator = '',
        inner_left_separator = '',
        inner_right_separator = '',
        separator_padding = ' ',
        sigil_leading_padding = ' ',
        gap_padding = '',
        side = 'left',
        base = { fg = '#565f89', bg = '#1f2335' },
        outer = { fg = '#7aa2f7', bg = '#24283b', bold = true },
        inner = { fg = '#c0caf5', bg = '#1f2335' },
    },
}

--- @type table<string, table<statuesque.Surface, statuesque.BackendDefaults>>
local STYLE_DEFAULTS = {
    slanted = {
        statusline = {
            left_separator = '',
            right_separator = '',
            inner_left_separator = '',
            inner_right_separator = '',
            right_gapped_separator = 'right',
        },
        tabline = {
            left_separator = '',
            right_separator = '',
            inner_left_separator = '',
            inner_right_separator = '',
            right_gapped_separator = 'right',
        },
        winbar = {
            left_separator = '',
            right_separator = '',
            inner_left_separator = '',
            inner_right_separator = '',
            right_gapped_separator = 'right',
        },
        incline = {
            left_separator = '',
            right_separator = '',
            inner_left_separator = '',
            inner_right_separator = '',
            right_gapped_separator = 'right',
        },
    },
    capsule = {
        statusline = {
            left_separator = '',
            right_separator = '',
            inner_left_separator = '',
            inner_right_separator = '',
            separator_padding = '',
            sigil_padding = ' ',
            gap_padding = ' ',
            right_gapped_separator = 'left',
            sigil = '',
        },
        tabline = {
            left_separator = '',
            right_separator = '',
            inner_left_separator = '',
            inner_right_separator = '',
            separator_padding = '',
            sigil_padding = ' ',
            gap_padding = ' ',
            right_gapped_separator = 'left',
            sigil = '',
            tabulature_sigil = '𝄞',
        },
        winbar = {
            left_separator = '',
            right_separator = '',
            inner_left_separator = '',
            inner_right_separator = '',
            separator_padding = '',
            sigil_padding = ' ',
            gap_padding = ' ',
            right_gapped_separator = 'left',
        },
        incline = {
            left_separator = '',
            right_separator = '',
            inner_left_separator = '',
            inner_right_separator = '',
            separator_padding = '',
            sigil_padding = ' ',
            gap_padding = ' ',
            right_gapped_separator = 'left',
        },
    },
}

--- @type table<string, statuesque.ModeName>
local MODE_NAMES = {
    n = 'normal',
    no = 'normal',
    nov = 'normal',
    noV = 'normal',
    ['no\22'] = 'normal',
    niI = 'normal',
    niR = 'normal',
    niV = 'normal',
    nt = 'normal',
    v = 'visual',
    V = 'visual',
    ['\22'] = 'visual',
    s = 'visual',
    S = 'visual',
    ['\19'] = 'visual',
    i = 'insert',
    ic = 'insert',
    ix = 'insert',
    R = 'replace',
    Rc = 'replace',
    Rv = 'replace',
    Rx = 'replace',
    c = 'command',
    cv = 'command',
    ce = 'command',
    r = 'replace',
    rm = 'replace',
    ['r?'] = 'replace',
    t = 'terminal',
}

--- @type table<statuesque.ModeName, statuesque.HighlightSpec>
local MODE_FALLBACKS = {
    normal = { fg = '#1a1b26', bg = '#7aa2f7', bold = true },
    insert = { fg = '#1a1b26', bg = '#9ece6a', bold = true },
    visual = { fg = '#1a1b26', bg = '#bb9af7', bold = true },
    replace = { fg = '#1a1b26', bg = '#f7768e', bold = true },
    command = { fg = '#1a1b26', bg = '#e0af68', bold = true },
    terminal = { fg = '#1a1b26', bg = '#7dcfff', bold = true },
}

--- @param value any
--- @return integer? red
--- @return integer? green
--- @return integer? blue
local function hex_to_rgb(value)
    if type(value) ~= 'string' then
        return nil
    end

    local hex = value:match('^#?(%x%x%x%x%x%x)$')
    if hex == nil then
        return nil
    end

    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

--- @param red integer
--- @param green integer
--- @param blue integer
--- @return string
local function rgb_to_hex(red, green, blue)
    return ('#%02x%02x%02x'):format(red, green, blue)
end

--- @param channel integer
--- @return number
local function relative_channel(channel)
    local value = channel / 255
    if value <= 0.03928 then
        return value / 12.92
    end
    return ((value + 0.055) / 1.055) ^ 2.4
end

--- @param color any
--- @return number?
local function relative_luminance(color)
    local red, green, blue = hex_to_rgb(color)
    if red == nil then
        return nil
    end
    --- @cast green integer
    --- @cast blue integer

    return 0.2126 * relative_channel(red) + 0.7152 * relative_channel(green) + 0.0722 * relative_channel(blue)
end

--- @param left any
--- @param right any
--- @return number?
local function contrast_ratio(left, right)
    local left_luminance = relative_luminance(left)
    local right_luminance = relative_luminance(right)
    if left_luminance == nil or right_luminance == nil then
        return nil
    end

    local lighter = math.max(left_luminance, right_luminance)
    local darker = math.min(left_luminance, right_luminance)
    return (lighter + 0.05) / (darker + 0.05)
end

--- @param left integer
--- @param right integer
--- @param ratio number
--- @return integer
function M.interpolate_channel(left, right, ratio)
    return math.floor(left + (right - left) * ratio + 0.5)
end

--- @param left string?
--- @param right string?
--- @param ratio number
--- @return string?
function M.interpolate_color(left, right, ratio)
    local lr, lg, lb = hex_to_rgb(left)
    local rr, rg, rb = hex_to_rgb(right)

    if lr == nil or rr == nil then
        return ratio < 0.5 and left or right
    end
    --- @cast lg integer
    --- @cast lb integer
    --- @cast rg integer
    --- @cast rb integer

    return rgb_to_hex(
        M.interpolate_channel(lr, rr, ratio),
        M.interpolate_channel(lg, rg, ratio),
        M.interpolate_channel(lb, rb, ratio)
    )
end

--- @param value any
--- @param minimum number
--- @param maximum number
--- @return number?
local function clamp(value, minimum, maximum)
    value = tonumber(value)
    if value == nil then
        return nil
    end
    return math.max(minimum, math.min(maximum, value))
end

--- @param bg string
--- @param opts? statuesque.ComposeOptions
--- @return string
local function readable_foreground(bg, opts)
    opts = opts or {}
    local minimum = opts.min_contrast or opts.minimum_contrast or DEFAULT_MIN_CONTRAST
    local candidates = {
        opts.readable_dark or DEFAULT_READABLE_DARK,
        opts.readable_light or DEFAULT_READABLE_LIGHT,
        opts.hard_readable_dark or HARD_READABLE_DARK,
        opts.hard_readable_light or HARD_READABLE_LIGHT,
    }
    local best = candidates[1]
    local best_contrast = 0

    for _, candidate in ipairs(candidates) do
        local candidate_contrast = contrast_ratio(candidate, bg) or 0
        if candidate_contrast >= minimum then
            return candidate
        end
        if candidate_contrast > best_contrast then
            best = candidate
            best_contrast = candidate_contrast
        end
    end

    return best
end

--- @generic T
--- @param hl T
--- @param opts? statuesque.ComposeOptions
--- @return T|statuesque.HighlightSpec
local function ensure_readable_hl(hl, opts)
    opts = opts or {}
    if type(hl) ~= 'table' or hl.fg == nil or hl.bg == nil then
        return hl
    end

    local ratio = contrast_ratio(hl.fg, hl.bg)
    local minimum = opts.min_contrast or opts.minimum_contrast or DEFAULT_MIN_CONTRAST
    if ratio == nil or ratio >= minimum then
        return hl
    end

    local readable = {}
    for key, value in pairs(hl) do
        readable[key] = value
    end
    readable.fg = readable_foreground(hl.bg, opts)
    return readable
end

--- @param outer? statuesque.HighlightSpec
--- @param inner? statuesque.HighlightSpec
--- @param ratio number
--- @param opts? statuesque.ComposeOptions
--- @return statuesque.HighlightSpec
local function interpolate_hl(outer, inner, ratio, opts)
    outer = outer or {}
    inner = inner or {}
    return ensure_readable_hl({
        fg = M.interpolate_color(outer.fg, inner.fg, ratio),
        bg = M.interpolate_color(outer.bg, inner.bg, ratio),
        bold = ratio < 0.2 and outer.bold or inner.bold,
        italic = ratio < 0.5 and outer.italic or inner.italic,
    }, opts)
end

--- @generic T
--- @param value T
--- @return T
local function copy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copied = {}
    for key, child in pairs(value) do
        copied[key] = copy(child)
    end
    return copied
end

--- Normalize a Vim mode code to Statuesque's semantic mode names.
--- @param mode? string
--- @return statuesque.ModeName
function M.mode_name(mode)
    mode = mode or (vim and vim.fn and vim.fn.mode and vim.fn.mode(1)) or 'n'
    if MODE_FALLBACKS[mode] ~= nil then
        return mode
    end

    return MODE_NAMES[mode] or 'normal'
end

--- Return the highlight style for a semantic or raw Vim mode.
--- @param mode? string
--- @return statuesque.HighlightSpec
function M.mode_style(mode)
    local mode_name = M.mode_name(mode)

    if vim and vim.api and vim.api.nvim_get_hl then
        local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = 'lualine_a_' .. mode_name })
        if ok and type(hl) == 'table' and (hl.fg ~= nil or hl.bg ~= nil) then
            local fallback = MODE_FALLBACKS[mode_name] or MODE_FALLBACKS.normal
            return ensure_readable_hl({
                fg = hl.fg and ('#%06x'):format(hl.fg) or fallback.fg,
                bg = hl.bg and ('#%06x'):format(hl.bg) or fallback.bg,
                bold = hl.bold ~= nil and hl.bold or fallback.bold,
                italic = hl.italic ~= nil and hl.italic or fallback.italic,
            })
        end
    end

    return copy(MODE_FALLBACKS[mode_name] or MODE_FALLBACKS.normal)
end

--- Resolve backend visual defaults for a surface.
--- @param surface? statuesque.Surface
--- @param opts? statuesque.ComposeOptions|statuesque.RenderContext
--- @return statuesque.BackendDefaults
function M.backend_defaults(surface, opts)
    opts = opts or {}
    local defaults = copy(DEFAULTS[surface] or DEFAULTS.statusline)
    local configured_style = opts.style or require('statuesque.config').style()
    local style_defaults = STYLE_DEFAULTS[configured_style]
    if type(style_defaults) == 'table' and type(style_defaults[surface]) == 'table' then
        defaults = vim.tbl_deep_extend('force', defaults, style_defaults[surface])
    end
    if type(opts.backend_defaults) == 'table' then
        defaults = vim.tbl_deep_extend('force', defaults, opts.backend_defaults)
    end
    return defaults
end

--- Return the configured separator text, including separator padding.
--- @param kind statuesque.SeparatorKind
--- @param surface? statuesque.Surface
--- @param opts? statuesque.ComposeOptions|statuesque.RenderContext
--- @return string
function M.separator_text(kind, surface, opts)
    local defaults = M.backend_defaults(surface, opts)
    local side = opts and (opts.side or opts.separator_side) or defaults.side or 'left'
    local padding = defaults.separator_padding or ''
    local text
    if kind == 'inner' or kind == 'in_section' then
        if side == 'right' then
            text = defaults.inner_right_separator or defaults.right_separator or defaults.inner_left_separator or ' '
            return padding .. text .. padding
        end
        text = defaults.inner_left_separator or defaults.left_separator or defaults.inner_right_separator or ' '
        return padding .. text .. padding
    end
    if side == 'right' then
        text = defaults.right_separator or defaults.left_separator or ' '
        return padding .. text .. padding
    end
    text = defaults.left_separator or defaults.right_separator or ' '
    return padding .. text .. padding
end

--- @param surface statuesque.Surface
--- @param opts statuesque.ComposeOptions
--- @param base_outer? statuesque.HighlightSpec
--- @return statuesque.HighlightSpec
local function mode_outer_style(surface, opts, base_outer)
    local mode_style = opts.mode_style
    if mode_style == nil then
        mode_style = surface == 'statusline'
    end
    if mode_style == false then
        return base_outer or {}
    end

    local outer = copy(base_outer or {})
    local mode_hl = mode_style
    if mode_style == true then
        mode_hl = M.mode_style(opts.mode)
    elseif type(mode_style) == 'string' then
        mode_hl = M.mode_style(mode_style)
    end

    if type(mode_hl) ~= 'table' then
        return outer
    end

    return vim.tbl_deep_extend('force', outer, mode_hl)
end

--- Return per-segment highlight levels interpolated from outer to inner style.
--- @param count integer
--- @param surface? statuesque.Surface
--- @param opts? statuesque.ComposeOptions
--- @return statuesque.HighlightSpec[]
function M.highlight_levels(count, surface, opts)
    opts = opts or {}
    surface = surface or 'statusline'
    local defaults = M.backend_defaults(surface, opts)
    local outer = mode_outer_style(surface, opts, opts.outer or defaults.outer)
    local inner = opts.inner or defaults.inner
    local inner_mix = clamp(opts.inner_mix or defaults.inner_mix or DEFAULT_INNER_MIX, 0, 1)
    local levels = {}

    if count <= 1 then
        return { interpolate_hl(outer, inner, 0, opts) }
    end

    for index = 1, count do
        levels[index] = interpolate_hl(outer, inner, ((index - 1) / math.max(1, count - 1)) * inner_mix, opts)
    end

    return levels
end

--- @param surface statuesque.Surface
--- @param opts statuesque.ComposeOptions
--- @return statuesque.HighlightSpec
local function base_style(surface, opts)
    local defaults = M.backend_defaults(surface, opts)
    local base = opts.base
        or defaults.base
        or {
            fg = defaults.inner and defaults.inner.fg or nil,
            bg = defaults.inner and defaults.inner.bg or nil,
        }
    return ensure_readable_hl(copy(base), opts)
end

--- @param side statuesque.Side
--- @param left_hl? statuesque.Highlight
--- @param right_hl? statuesque.Highlight
--- @return statuesque.HighlightSpec
local function separator_highlight(side, left_hl, right_hl)
    local left_bg = type(left_hl) == 'table' and left_hl.bg or nil
    local right_bg = type(right_hl) == 'table' and right_hl.bg or nil

    if side == 'right' then
        return {
            fg = right_bg,
            bg = left_bg,
        }
    end

    return {
        fg = left_bg,
        bg = right_bg,
    }
end

--- @param role string
--- @param text string
--- @param left_hl? statuesque.Highlight
--- @param right_hl? statuesque.Highlight
--- @param defaults statuesque.BackendDefaults
--- @param side statuesque.Side
--- @param padding? string|{ before?: string, after?: string }
--- @return statuesque.NormalizedNode
local function separator_node(role, text, left_hl, right_hl, defaults, side, padding)
    if padding == nil then
        padding = defaults.separator_padding or ''
    end
    local before_padding = padding
    local after_padding = padding
    if type(padding) == 'table' then
        before_padding = padding.before or ''
        after_padding = padding.after or ''
    end
    local children = {}

    if before_padding ~= '' then
        children[#children + 1] = {
            role = role .. '-padding-before',
            text = before_padding,
            hl = left_hl,
        }
    end

    children[#children + 1] = {
        role = role .. '-glyph',
        text = text,
        hl = separator_highlight(side, left_hl, right_hl),
    }

    if after_padding ~= '' then
        children[#children + 1] = {
            role = role .. '-padding-after',
            text = after_padding,
            hl = right_hl,
        }
    end

    return {
        role = role,
        hl = right_hl,
        separator_side = side,
        separator_text = text,
        children = children,
    }
end

--- @param node statuesque.NormalizedNode
--- @return boolean
local function node_has_content(node)
    if node.text ~= nil and node.text ~= '' then
        return true
    end
    if node.raw ~= nil and node.raw ~= '' then
        return true
    end
    if node.separator ~= nil then
        return true
    end
    if node.children ~= nil then
        for _, child in ipairs(node.children) do
            if node_has_content(child) then
                return true
            end
        end
    end
    return false
end

--- @param nodes statuesque.NormalizedNode[]
--- @return boolean
local function nodes_have_content(nodes)
    for _, node in ipairs(nodes) do
        if node_has_content(node) then
            return true
        end
    end
    return false
end

--- @param base_opts? statuesque.ComposeOptions
--- @param context? table
--- @return statuesque.ComposeOptions
local function merged_opts(base_opts, context)
    local merged = copy(base_opts or {})
    if type(context) == 'table' then
        merged = vim.tbl_deep_extend('force', merged, context)
    elseif context ~= nil then
        merged.context = context
    end
    return merged
end

--- @class statuesque.PreparedComponent
--- @field component statuesque.RenderSpec
--- @field custom_rendered boolean
--- @field nodes statuesque.NormalizedNode[]

--- @param component statuesque.RenderSpec
--- @param nodes statuesque.NormalizedNode[]
--- @return boolean
local function custom_rendered(component, nodes)
    if type(component) == 'table' and component.custom_rendered == true then
        return true
    end

    return #nodes == 1 and nodes[1].custom_rendered == true
end

--- @param components? statuesque.RenderSpec[]
--- @param opts statuesque.RenderContext|statuesque.ComposeOptions
--- @return statuesque.PreparedComponent[]
local function prepared_components(components, opts)
    local prepared = {}
    for _, component in ipairs(components or {}) do
        local nodes = spec.normalize(component, opts)
        if nodes_have_content(nodes) then
            prepared[#prepared + 1] = {
                component = component,
                custom_rendered = custom_rendered(component, nodes),
                nodes = nodes,
            }
        end
    end
    return prepared
end

--- @param prepared statuesque.PreparedComponent
--- @param level statuesque.HighlightSpec
--- @param level_index integer
--- @param surface statuesque.Surface
--- @return statuesque.NormalizedNode
local function section_node(prepared, level, level_index, surface)
    if prepared.custom_rendered then
        if #prepared.nodes == 1 then
            local node = prepared.nodes[1]
            node.custom_rendered = true
            return node
        end

        return {
            role = 'custom-rendered-fragment',
            custom_rendered = true,
            children = prepared.nodes,
        }
    end

    local component = prepared.component
    if type(component) == 'table' and component.hl ~= nil then
        if #prepared.nodes == 1 then
            return prepared.nodes[1]
        end
        return {
            role = 'section',
            hl = component.hl,
            children = prepared.nodes,
        }
    end

    return {
        role = 'section',
        hl = level,
        style = {
            statuesque = 'section',
            surface = surface,
            level = level_index,
        },
        children = prepared.nodes,
    }
end

--- @generic T
--- @param values T[]
--- @return T[]
local function reverse_list(values)
    local reversed = {}
    for index = #values, 1, -1 do
        reversed[#reversed + 1] = values[index]
    end
    return reversed
end

--- @param nodes statuesque.NormalizedNode[]
--- @param defaults statuesque.BackendDefaults
--- @return statuesque.NormalizedNode[]
local function append_right_edge_padding(nodes, defaults)
    local padding = defaults.separator_padding or ''
    if padding == '' then
        return nodes
    end

    local final = nodes[#nodes]
    nodes[#nodes + 1] = {
        role = 'right-edge-padding',
        text = padding,
        hl = final and final.hl or nil,
    }
    return nodes
end

--- @type table<string, string>
local DIAGONAL_REVERSE_SEPARATORS = {
    [''] = '',
    [''] = '',
    [''] = '',
    [''] = '',
    [''] = '',
    [''] = '',
}

--- @param text string
--- @return string
local function diagonal_reverse_separator(text)
    return DIAGONAL_REVERSE_SEPARATORS[text] or text
end

--- @param nodes statuesque.NormalizedNode[]
--- @param prepared statuesque.PreparedComponent[]
--- @param levels statuesque.HighlightSpec[]
--- @param defaults statuesque.BackendDefaults
--- @param surface statuesque.Surface
--- @param sigil_added boolean
--- @param opts statuesque.ComposeOptions
--- @return statuesque.NormalizedNode[]
local function append_gapped_left(nodes, prepared, levels, defaults, surface, sigil_added, opts)
    local base_hl = base_style(surface, opts)
    local gap_padding = opts.gap_padding
    if gap_padding == nil then
        gap_padding = defaults.gap_padding or ''
    end
    local separator_padding = defaults.separator_padding or ''
    local trailing_separator = defaults.left_separator or defaults.right_separator or ' '
    local leading_separator = diagonal_reverse_separator(trailing_separator)

    if sigil_added and #prepared > 0 then
        local sigil = nodes[#nodes]
        nodes[#nodes + 1] = separator_node('base-separator', trailing_separator, sigil.hl, base_hl, defaults, 'left', {
            before = separator_padding,
        })
        if gap_padding ~= '' and not prepared[1].custom_rendered then
            nodes[#nodes + 1] = {
                role = 'segment-gap',
                text = gap_padding,
                hl = base_hl,
            }
        end
    end

    for index, prepared_component in ipairs(prepared) do
        local level = levels[index]
        if
            not prepared_component.custom_rendered and not (prepared[index - 1] and prepared[index - 1].custom_rendered)
        then
            nodes[#nodes + 1] =
                separator_node('segment-leading-separator', leading_separator, base_hl, level, defaults, 'right', {
                    after = separator_padding,
                })
        end
        nodes[#nodes + 1] = section_node(prepared_component, level, index, surface)
        if not prepared_component.custom_rendered then
            nodes[#nodes + 1] =
                separator_node('segment-trailing-separator', trailing_separator, level, base_hl, defaults, 'left', {
                    before = separator_padding,
                })
        end
        if
            gap_padding ~= ''
            and index < #prepared
            and not prepared_component.custom_rendered
            and not prepared[index + 1].custom_rendered
        then
            nodes[#nodes + 1] = {
                role = 'segment-gap',
                text = gap_padding,
                hl = base_hl,
            }
        end
    end

    return nodes
end

--- @param nodes statuesque.NormalizedNode[]
--- @param prepared statuesque.PreparedComponent[]
--- @param levels statuesque.HighlightSpec[]
--- @param defaults statuesque.BackendDefaults
--- @param surface statuesque.Surface
--- @param opts statuesque.ComposeOptions
--- @return statuesque.NormalizedNode[]
local function append_gapped_right(nodes, prepared, levels, defaults, surface, opts)
    local base_hl = base_style(surface, opts)
    local gap_padding = opts.gap_padding
    if gap_padding == nil then
        gap_padding = defaults.gap_padding or ''
    end
    local separator_padding = defaults.separator_padding or ''
    local trailing_separator = defaults.right_separator or defaults.left_separator or ' '
    local trailing_side = 'right'
    local leading_side = 'left'
    if defaults.right_gapped_separator == 'left' then
        trailing_separator = defaults.left_separator or defaults.right_separator or ' '
        trailing_side = 'left'
        leading_side = 'right'
    end
    local leading_separator = diagonal_reverse_separator(trailing_separator)

    for index, prepared_component in ipairs(prepared) do
        local level = levels[index]
        if index > 1 and not prepared_component.custom_rendered and not prepared[index - 1].custom_rendered then
            nodes[#nodes + 1] = separator_node(
                'segment-trailing-separator',
                trailing_separator,
                level,
                base_hl,
                defaults,
                trailing_side,
                {
                    before = separator_padding,
                }
            )
        end
        nodes[#nodes + 1] = section_node(prepared_component, level, index, surface)
        if not prepared_component.custom_rendered then
            nodes[#nodes + 1] =
                separator_node('segment-leading-separator', leading_separator, base_hl, level, defaults, leading_side, {
                    after = separator_padding,
                })
        end
        if
            gap_padding ~= ''
            and index < #prepared
            and not prepared_component.custom_rendered
            and not prepared[index + 1].custom_rendered
        then
            nodes[#nodes + 1] = {
                role = 'segment-gap',
                text = gap_padding,
                hl = base_hl,
            }
        end
    end

    return nodes
end

--- @param opts statuesque.ComposeOptions
--- @return statuesque.SegmentLayout
local function segment_layout(opts)
    return opts.segment_layout or opts.layout or 'gapped'
end

--- @class statuesque.SideDefinition
--- @field side statuesque.Side
--- @field sigil? boolean
--- @field separator fun(defaults: statuesque.BackendDefaults): string
--- @field left_hl fun(previous_hl?: statuesque.Highlight, next_hl?: statuesque.Highlight): statuesque.Highlight?
--- @field right_hl fun(previous_hl?: statuesque.Highlight, next_hl?: statuesque.Highlight): statuesque.Highlight?
--- @field trailing_left_hl fun(final_hl?: statuesque.Highlight): statuesque.Highlight?
--- @field trailing_right_hl fun(final_hl?: statuesque.Highlight): statuesque.Highlight?
--- @field trailing_separator? boolean

--- @param prepared statuesque.PreparedComponent[]
--- @param opts statuesque.ComposeOptions
--- @param definition statuesque.SideDefinition
--- @return statuesque.NormalizedNode[]
local function compose_side(prepared, opts, definition)
    local surface = opts.surface or opts.target or 'statusline'
    local defaults = M.backend_defaults(surface, opts)
    local levels = M.highlight_levels(#prepared, surface, opts)
    local nodes = {}
    local sigil_added = false

    if definition.sigil ~= false then
        local sigil = opts.sigil
        if sigil == nil then
            sigil = defaults.sigil
        end

        if sigil ~= nil and sigil ~= '' then
            local sigil_padding = defaults.sigil_padding
            if sigil_padding == nil then
                sigil_padding = defaults.separator_padding or ''
            end
            local sigil_leading_padding = defaults.sigil_leading_padding
            if sigil_leading_padding == nil then
                sigil_leading_padding = ' '
            end
            nodes[#nodes + 1] = {
                role = 'sigil',
                text = sigil_leading_padding .. sigil .. sigil_padding,
                hl = opts.sigil_hl or defaults.sigil_hl or 'StatuesqueSigil',
                style = { statuesque = 'sigil', surface = surface },
            }
            sigil_added = true
        end
    end

    if segment_layout(opts) ~= 'adjacent' then
        if definition.side == 'right' then
            return append_gapped_right(nodes, prepared, levels, defaults, surface, opts)
        end
        return append_gapped_left(nodes, prepared, levels, defaults, surface, sigil_added, opts)
    end

    for index, prepared_component in ipairs(prepared) do
        local level = levels[index]
        if #nodes > 0 and not prepared_component.custom_rendered then
            local previous = nodes[#nodes]
            if previous.custom_rendered ~= true then
                nodes[#nodes + 1] = separator_node(
                    'separator',
                    definition.separator(defaults),
                    definition.left_hl(previous.hl, level),
                    definition.right_hl(previous.hl, level),
                    defaults,
                    definition.side
                )
            end
        end

        nodes[#nodes + 1] = section_node(prepared_component, level, index, surface)
    end

    if #prepared > 0 and definition.trailing_separator ~= false then
        local final = nodes[#nodes]
        if final.custom_rendered ~= true then
            nodes[#nodes + 1] = separator_node(
                'trailing-separator',
                definition.separator(defaults),
                definition.trailing_left_hl(final.hl),
                definition.trailing_right_hl(final.hl),
                defaults,
                definition.side
            )
        end
    end

    return nodes
end

--- @type table<'left'|'right', statuesque.SideDefinition>
local SIDE_DEFINITIONS = {
    left = {
        side = 'left',
        separator = function(defaults)
            return defaults.left_separator or defaults.right_separator or ' '
        end,
        left_hl = function(previous_hl)
            return previous_hl
        end,
        right_hl = function(_, next_hl)
            return next_hl
        end,
        trailing_left_hl = function(final_hl)
            return final_hl
        end,
        trailing_right_hl = function()
            return nil
        end,
    },
    right = {
        side = 'right',
        sigil = false,
        separator = function(defaults)
            return defaults.right_separator or defaults.left_separator or ' '
        end,
        left_hl = function(_, next_hl)
            return next_hl
        end,
        right_hl = function(previous_hl)
            return previous_hl
        end,
        trailing_left_hl = function()
            return nil
        end,
        trailing_right_hl = function(final_hl)
            return final_hl
        end,
    },
}

--- @param name 'left'|'right'
--- @param trailing_separator boolean
--- @return statuesque.SideDefinition
local function side_definition(name, trailing_separator)
    local definition = copy(SIDE_DEFINITIONS[name])
    definition.trailing_separator = trailing_separator
    return definition
end

--- @param components statuesque.ComposeInput
--- @param opts statuesque.ComposeOptions
--- @return statuesque.NormalizedNode[]
local function compose_resolved(components, opts)
    local surface = opts.surface or opts.target or 'statusline'
    local defaults = M.backend_defaults(surface, opts)

    if components.left ~= nil or components.right ~= nil then
        local composed = compose_side(
            prepared_components(components.left or {}, opts),
            opts,
            side_definition('left', opts.trailing_separator ~= false)
        )
        local right_components = prepared_components(components.right or {}, opts)

        if #right_components > 0 then
            composed[#composed + 1] = {
                role = 'align-right',
                align = 'right',
            }

            local right = compose_side(
                reverse_list(right_components),
                opts,
                side_definition('right', opts.right_leading_separator ~= false)
            )
            right = reverse_list(right)
            for _, node in ipairs(right) do
                composed[#composed + 1] = node
            end
        end

        return append_right_edge_padding(composed, defaults)
    end

    local side = opts.side or opts.separator_side or 'left'
    local prepared = prepared_components(components, opts)
    if side == 'right' then
        return append_right_edge_padding(
            reverse_list(
                compose_side(reverse_list(prepared), opts, side_definition('right', opts.leading_separator ~= false))
            ),
            defaults
        )
    end
    return append_right_edge_padding(
        compose_side(prepared, opts, side_definition('left', opts.trailing_separator ~= false)),
        defaults
    )
end

--- Compose a styled statusline-family render spec.
--- @param components statuesque.ComposeInput
--- @param opts? statuesque.ComposeOptions
--- @return statuesque.RenderNode
function M.compose(components, opts)
    opts = opts or {}
    return {
        role = 'composed-bar',
        render = function(context)
            return compose_resolved(components or {}, merged_opts(opts, context))
        end,
    }
end

--- Install Statuesque's default highlight groups.
--- @return nil
function M.define_default_highlights()
    if vim == nil or vim.api == nil or vim.api.nvim_set_hl == nil then
        return
    end

    local normal = M.mode_style('n')
    local inactive = DEFAULTS.statusline.inner or {}
    vim.api.nvim_set_hl(0, 'StatuesqueMode', normal)
    vim.api.nvim_set_hl(0, 'StatuesqueSigil', DEFAULTS.statusline.sigil_hl)
    vim.api.nvim_set_hl(0, 'StatuesqueSection', inactive)
    vim.api.nvim_set_hl(0, 'StatuesqueSubtle', { fg = '#565f89', bg = inactive.bg })
    vim.api.nvim_set_hl(0, 'StatuesqueWarning', { fg = '#e0af68', bg = inactive.bg, bold = true })
    vim.api.nvim_set_hl(0, 'StatuesqueError', { fg = '#f7768e', bg = inactive.bg, bold = true })
end

return M

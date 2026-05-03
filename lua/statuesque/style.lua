local spec = require('statuesque.spec')

local M = {}

local DEFAULT_MIN_CONTRAST = 4.5
local DEFAULT_SEMANTIC_MIN_CONTRAST = 3.5
local DEFAULT_INNER_MIX = 0.85
local DEFAULT_PALETTE_DISTANCE_TOLERANCE = 28
local DEFAULT_READABLE_DARK = '#1a1b26'
local DEFAULT_READABLE_LIGHT = '#c0caf5'
local HARD_READABLE_DARK = '#000000'
local HARD_READABLE_LIGHT = '#ffffff'
local SEMANTIC_REPAIR_DIRECTIONS = { 'exact', 'dark', 'light' }
local OKLCH_CHROMA_EPSILON = 0.015
local OKLCH_MIN_SEMANTIC_CHROMA_RATIO = 0.55
local semantic_candidate_cache = {}
--- @type statuesque.HighlightSpec
local DEFAULT_SIGIL_HL = { fg = '#1a1b26', bg = '#ff9e64', bold = true }
local readable_foreground
local hue_preserving_foreground
local semantic_repair_candidate
local rgb_to_oklab
local oklab_to_hex
local rgb_to_oklch
local oklch_to_hex
local hue_distance
local interpolate_hue
local oklab_distance

local DEFAULT_PALETTE_GROUPS = {
    'Normal',
    'Comment',
    'Constant',
    'String',
    'Character',
    'Number',
    'Boolean',
    'Float',
    'Identifier',
    'Function',
    'Statement',
    'Conditional',
    'Repeat',
    'Label',
    'Operator',
    'Keyword',
    'Exception',
    'PreProc',
    'Include',
    'Define',
    'Macro',
    'PreCondit',
    'Type',
    'StorageClass',
    'Structure',
    'Typedef',
    'Special',
    'SpecialChar',
    'Tag',
    'Delimiter',
    'SpecialComment',
    'Debug',
    'Underlined',
    'Todo',
    'Directory',
    'Title',
    'Question',
    'MoreMsg',
    'WarningMsg',
    'ErrorMsg',
    'DiagnosticOk',
    'DiagnosticInfo',
    'DiagnosticHint',
    'DiagnosticWarn',
    'DiagnosticError',
    'GitSignsAdd',
    'GitSignsChange',
    'GitSignsDelete',
    'DiffAdd',
    'DiffChange',
    'DiffDelete',
    'DiffText',
    'LineNr',
    'NonText',
}

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

--- @param red integer
--- @param green integer
--- @param blue integer
--- @return number
local function rgb_chroma(red, green, blue)
    return (math.max(red, green, blue) - math.min(red, green, blue)) / 255
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

--- @param red integer
--- @param green integer
--- @param blue integer
--- @return number hue
--- @return number saturation
--- @return number lightness
local function rgb_to_hsl(red, green, blue)
    local r = red / 255
    local g = green / 255
    local b = blue / 255
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local lightness = (max + min) / 2

    if max == min then
        return 0, 0, lightness
    end

    local delta = max - min
    local saturation = lightness > 0.5 and delta / (2 - max - min) or delta / (max + min)
    local hue

    if max == r then
        hue = (g - b) / delta + (g < b and 6 or 0)
    elseif max == g then
        hue = (b - r) / delta + 2
    else
        hue = (r - g) / delta + 4
    end

    return hue / 6, saturation, lightness
end

--- @param p number
--- @param q number
--- @param t number
--- @return number
local function hue_to_rgb(p, q, t)
    if t < 0 then
        t = t + 1
    end
    if t > 1 then
        t = t - 1
    end
    if t < 1 / 6 then
        return p + (q - p) * 6 * t
    end
    if t < 1 / 2 then
        return q
    end
    if t < 2 / 3 then
        return p + (q - p) * (2 / 3 - t) * 6
    end
    return p
end

--- @param hue number
--- @param saturation number
--- @param lightness number
--- @return string
local function hsl_to_hex(hue, saturation, lightness)
    local r
    local g
    local b

    if saturation == 0 then
        r = lightness
        g = lightness
        b = lightness
    else
        local q = lightness < 0.5 and lightness * (1 + saturation) or lightness + saturation - lightness * saturation
        local p = 2 * lightness - q
        r = hue_to_rgb(p, q, hue + 1 / 3)
        g = hue_to_rgb(p, q, hue)
        b = hue_to_rgb(p, q, hue - 1 / 3)
    end

    return rgb_to_hex(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
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

    local left_lch = rgb_to_oklch(left)
    local right_lch = rgb_to_oklch(right)
    if left_lch ~= nil and right_lch ~= nil then
        local chroma = left_lch.chroma + (right_lch.chroma - left_lch.chroma) * ratio
        local lightness = left_lch.lightness + (right_lch.lightness - left_lch.lightness) * ratio
        local color

        if
            left_lch.chroma > OKLCH_CHROMA_EPSILON
            and right_lch.chroma > OKLCH_CHROMA_EPSILON
            and hue_distance(left_lch.hue, right_lch.hue) <= 0.75
        then
            local hue = interpolate_hue(left_lch.hue, right_lch.hue, ratio)
            color = oklch_to_hex(lightness, chroma, hue)
            while color == nil and chroma > 0 do
                chroma = chroma * 0.92
                color = oklch_to_hex(lightness, chroma, hue)
            end
        else
            local left_lab = rgb_to_oklab(left)
            local right_lab = rgb_to_oklab(right)
            if left_lab ~= nil and right_lab ~= nil then
                color = oklab_to_hex(
                    left_lab.lightness + (right_lab.lightness - left_lab.lightness) * ratio,
                    left_lab.a + (right_lab.a - left_lab.a) * ratio,
                    left_lab.b + (right_lab.b - left_lab.b) * ratio
                )
            end
        end

        if color ~= nil then
            return color
        end
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

--- @param value any
--- @return string?
local function color_value(value)
    if type(value) == 'number' then
        return ('#%06x'):format(value)
    end
    if type(value) == 'string' then
        if value:match('^#%x%x%x%x%x%x$') then
            return value
        end
        if value:match('^%x%x%x%x%x%x$') then
            return '#' .. value
        end
    end
    return nil
end

--- @param pivot number
--- @return number
local function xyz_pivot(pivot)
    if pivot > 0.008856 then
        return pivot ^ (1 / 3)
    end
    return (7.787 * pivot) + (16 / 116)
end

--- @param color string
--- @return { lightness: number, a: number, b: number }?
local function rgb_to_lab(color)
    local red, green, blue = hex_to_rgb(color)
    if red == nil then
        return nil
    end
    --- @cast green integer
    --- @cast blue integer

    local r = relative_channel(red)
    local g = relative_channel(green)
    local b = relative_channel(blue)

    local x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    local y = r * 0.2126 + g * 0.7152 + b * 0.0722
    local z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883

    local fx = xyz_pivot(x)
    local fy = xyz_pivot(y)
    local fz = xyz_pivot(z)

    return {
        lightness = (116 * fy) - 16,
        a = 500 * (fx - fy),
        b = 200 * (fy - fz),
    }
end

--- @param left string
--- @param right string
--- @return number
local function lab_distance(left, right)
    local left_lab = rgb_to_lab(left)
    local right_lab = rgb_to_lab(right)
    if left_lab == nil or right_lab == nil then
        return math.huge
    end

    local lightness = (left_lab.lightness - right_lab.lightness) * 1.75
    local chroma_a = left_lab.a - right_lab.a
    local chroma_b = left_lab.b - right_lab.b
    return math.sqrt(lightness * lightness + chroma_a * chroma_a + chroma_b * chroma_b)
end

--- @param color string
--- @return number
local function color_chroma(color)
    local red, green, blue = hex_to_rgb(color)
    if red == nil then
        return 0
    end
    --- @cast green integer
    --- @cast blue integer

    return rgb_chroma(red, green, blue)
end

--- @param color string
--- @return number
local function color_lightness(color)
    local red, green, blue = hex_to_rgb(color)
    if red == nil then
        return 0.5
    end
    --- @cast green integer
    --- @cast blue integer

    local _, _, lightness = rgb_to_hsl(red, green, blue)
    return lightness
end

--- @param source string
--- @param candidate string
--- @return number
local function color_identity_distance(source, candidate)
    local source_chroma = color_chroma(source)
    local candidate_lightness = color_lightness(candidate)
    local chroma_loss = math.max(0, source_chroma - color_chroma(candidate))
    local endpoint_penalty = math.max(0, candidate_lightness - 0.9, 0.1 - candidate_lightness)

    return lab_distance(source, candidate) + (chroma_loss * 80) + (endpoint_penalty * 120)
end

--- @param channel integer
--- @return number
local function srgb_to_linear_channel(channel)
    local value = channel / 255
    if value <= 0.04045 then
        return value / 12.92
    end
    return ((value + 0.055) / 1.055) ^ 2.4
end

--- @param value number
--- @return integer
local function linear_to_srgb_channel(value)
    value = math.max(0, math.min(1, value))
    local srgb
    if value <= 0.0031308 then
        srgb = 12.92 * value
    else
        srgb = (1.055 * (value ^ (1 / 2.4))) - 0.055
    end
    return math.floor(math.max(0, math.min(1, srgb)) * 255 + 0.5)
end

--- @class statuesque.OklabColor
--- @field lightness number
--- @field a number
--- @field b number

--- @class statuesque.OklchColor
--- @field lightness number
--- @field chroma number
--- @field hue number

--- @param color string
--- @return statuesque.OklabColor?
function rgb_to_oklab(color)
    local red, green, blue = hex_to_rgb(color)
    if red == nil then
        return nil
    end
    --- @cast green integer
    --- @cast blue integer

    local r = srgb_to_linear_channel(red)
    local g = srgb_to_linear_channel(green)
    local b = srgb_to_linear_channel(blue)

    local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    local l_root = l ^ (1 / 3)
    local m_root = m ^ (1 / 3)
    local s_root = s ^ (1 / 3)

    return {
        lightness = 0.2104542553 * l_root + 0.7936177850 * m_root - 0.0040720468 * s_root,
        a = 1.9779984951 * l_root - 2.4285922050 * m_root + 0.4505937099 * s_root,
        b = 0.0259040371 * l_root + 0.7827717662 * m_root - 0.8086757660 * s_root,
    }
end

--- @param lightness number
--- @param a number
--- @param b number
--- @return string?
function oklab_to_hex(lightness, a, b)
    local l_root = lightness + 0.3963377774 * a + 0.2158037573 * b
    local m_root = lightness - 0.1055613458 * a - 0.0638541728 * b
    local s_root = lightness - 0.0894841775 * a - 1.2914855480 * b

    local l = l_root * l_root * l_root
    local m = m_root * m_root * m_root
    local s = s_root * s_root * s_root

    local red = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    local green = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    local blue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    local epsilon = 0.000001
    if
        red < -epsilon
        or green < -epsilon
        or blue < -epsilon
        or red > 1 + epsilon
        or green > 1 + epsilon
        or blue > 1 + epsilon
    then
        return nil
    end

    return rgb_to_hex(linear_to_srgb_channel(red), linear_to_srgb_channel(green), linear_to_srgb_channel(blue))
end

--- @param color string
--- @return statuesque.OklchColor?
function rgb_to_oklch(color)
    local lab = rgb_to_oklab(color)
    if lab == nil then
        return nil
    end

    return {
        lightness = lab.lightness,
        chroma = math.sqrt(lab.a * lab.a + lab.b * lab.b),
        hue = math.atan2(lab.b, lab.a),
    }
end

--- @param lightness number
--- @param chroma number
--- @param hue number
--- @return string?
function oklch_to_hex(lightness, chroma, hue)
    return oklab_to_hex(lightness, chroma * math.cos(hue), chroma * math.sin(hue))
end

--- @param left number
--- @param right number
--- @return number
function hue_distance(left, right)
    local delta = math.abs(left - right) % (math.pi * 2)
    return math.min(delta, (math.pi * 2) - delta)
end

--- @param left number
--- @param right number
--- @param ratio number
--- @return number
function interpolate_hue(left, right, ratio)
    local delta = (right - left) % (math.pi * 2)
    if delta > math.pi then
        delta = delta - (math.pi * 2)
    end
    return left + delta * ratio
end

--- @param left string
--- @param right string
--- @return number
function oklab_distance(left, right)
    local left_lab = rgb_to_oklab(left)
    local right_lab = rgb_to_oklab(right)
    if left_lab == nil or right_lab == nil then
        return math.huge
    end

    local lightness = left_lab.lightness - right_lab.lightness
    local a = left_lab.a - right_lab.a
    local b = left_lab.b - right_lab.b
    return math.sqrt(lightness * lightness + a * a + b * b)
end

--- @param source string
--- @param candidate string
--- @return boolean
local function palette_candidate_preserves_identity(source, candidate)
    local source_lch = rgb_to_oklch(source)
    local candidate_lch = rgb_to_oklch(candidate)
    if source_lch == nil or candidate_lch == nil then
        return false
    end

    if source_lch.chroma <= OKLCH_CHROMA_EPSILON then
        return true
    end
    if candidate_lch.chroma < source_lch.chroma * 0.35 then
        return false
    end
    if candidate_lch.chroma > OKLCH_CHROMA_EPSILON and hue_distance(source_lch.hue, candidate_lch.hue) > 0.7 then
        return false
    end

    return true
end

--- @param colors table
--- @param output string[]
--- @param seen table<string, boolean>
local function collect_palette_colors(colors, output, seen)
    for key, value in pairs(colors) do
        if type(key) ~= 'number' then
            local key_color = color_value(key)
            if key_color ~= nil and not seen[key_color] then
                seen[key_color] = true
                output[#output + 1] = key_color
            end
        end

        local color = color_value(value)
        if color ~= nil and not seen[color] then
            seen[color] = true
            output[#output + 1] = color
        end
    end
end

--- @return string[]
local function derive_default_palette()
    local colors = {}
    local seen = {}

    if vim ~= nil and vim.api ~= nil and vim.api.nvim_get_hl ~= nil then
        for _, group in ipairs(DEFAULT_PALETTE_GROUPS) do
            local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
            if ok and type(hl) == 'table' then
                for _, field in ipairs({ 'fg', 'bg', 'sp' }) do
                    local color = color_value(hl[field])
                    if color ~= nil and not seen[color] then
                        seen[color] = true
                        colors[#colors + 1] = color
                    end
                end
            end
        end
    end

    if #colors == 0 then
        colors = {
            '#7aa2f7',
            '#bb9af7',
            '#9ece6a',
            '#e0af68',
            '#f7768e',
            '#7dcfff',
            '#c0caf5',
            '#565f89',
        }
    end

    return colors
end

--- @param opts? statuesque.ComposeOptions
--- @return string[]
local function resolve_palette(opts)
    opts = opts or {}
    local cached_palette = rawget(opts, '__statuesque_resolved_palette')
    if cached_palette ~= nil then
        return cached_palette
    end

    --- @param colors string[]
    --- @return string[]
    local function finish(colors)
        if type(opts) == 'table' then
            opts.__statuesque_resolved_palette = colors
            opts.__statuesque_palette_key = table.concat(colors, ',')
        end
        return colors
    end

    local palette = opts.palette
    if palette == nil then
        local ok, config = pcall(require, 'statuesque.config')
        if ok and type(config.config) == 'table' then
            palette = config.config.palette
        end
    end
    if palette == false then
        return finish({})
    end
    if type(palette) == 'function' then
        local ok, result = pcall(palette)
        palette = ok and result or nil
    end

    if type(palette) ~= 'table' then
        return finish(derive_default_palette())
    end

    local colors = {}
    collect_palette_colors(palette, colors, {})
    if #colors == 0 then
        return finish(derive_default_palette())
    end
    return finish(colors)
end

--- @param fg string
--- @param bg? string
--- @param opts? statuesque.ComposeOptions
--- @return string
local function palette_harmony_anchor(fg, bg, opts)
    local palette = resolve_palette(opts)
    if #palette == 0 then
        return fg
    end

    local minimum = opts and (opts.min_contrast or opts.minimum_contrast) or DEFAULT_MIN_CONTRAST
    local best
    local best_distance = math.huge
    local best_any = fg
    local best_any_distance = math.huge

    for _, candidate in ipairs(palette) do
        local distance = color_identity_distance(fg, candidate)
        if distance < best_any_distance then
            best_any = candidate
            best_any_distance = distance
        end

        if bg == nil or (contrast_ratio(candidate, bg) or 0) >= minimum then
            if distance < best_distance then
                best = candidate
                best_distance = distance
            end
        end
    end

    return best or best_any
end

--- @param opts? statuesque.ComposeOptions
--- @return number
local function palette_distance_tolerance(opts)
    return opts and tonumber(opts.palette_distance_tolerance) or DEFAULT_PALETTE_DISTANCE_TOLERANCE
end

--- @param opts? statuesque.ComposeOptions
--- @return 'dark'|'light'
local function editor_background(opts)
    if opts and (opts.semantic_background == 'dark' or opts.semantic_background == 'light') then
        return opts.semantic_background
    end
    if vim ~= nil and vim.o ~= nil and (vim.o.background == 'dark' or vim.o.background == 'light') then
        return vim.o.background
    end
    return 'dark'
end

--- @param bg string
--- @param opts? statuesque.ComposeOptions
--- @return 'dark'|'light'
local function preferred_direction_for_background(bg, opts)
    local luminance = relative_luminance(bg) or 0.5
    local option = editor_background(opts)

    if option == 'light' then
        return luminance >= 0.42 and 'dark' or 'light'
    end

    return luminance >= 0.18 and 'dark' or 'light'
end

--- @param opts? statuesque.ComposeOptions
--- @return statuesque.ComposeOptions
local function semantic_foreground_opts(opts)
    local semantic_opts = {}
    for key, value in pairs(opts or {}) do
        semantic_opts[key] = value
    end
    local minimum = semantic_opts.semantic_min_contrast
        or semantic_opts.accent_min_contrast
        or DEFAULT_SEMANTIC_MIN_CONTRAST
    semantic_opts.min_contrast = minimum
    semantic_opts.minimum_contrast = minimum
    return semantic_opts
end

--- @param fg string
--- @param bg string
--- @param opts? statuesque.ComposeOptions
--- @return string?
local function source_readable_foreground(fg, bg, opts)
    local minimum = opts and (opts.min_contrast or opts.minimum_contrast) or DEFAULT_MIN_CONTRAST
    if (contrast_ratio(fg, bg) or 0) >= minimum then
        return fg
    end

    return hue_preserving_foreground(fg, bg, opts)
end

--- Map a source color toward the current colorscheme if a compatible matcher is available.
---@param color string?
---@param opts? statuesque.ComposeOptions
---@return string?
function M.harmonize_color(color, opts)
    if type(color) ~= 'string' or not color:match('^#%x%x%x%x%x%x$') then
        return color
    end

    return palette_harmony_anchor(color, nil, opts)
end

--- Map a foreground to the active palette while preserving contrast against a background.
--- @param fg string?
--- @param bg string?
--- @param opts? statuesque.ComposeOptions
--- @return string?
function M.match_palette_color(fg, bg, opts)
    if type(fg) ~= 'string' or not fg:match('^#%x%x%x%x%x%x$') then
        return fg
    end
    if type(bg) ~= 'string' or not bg:match('^#%x%x%x%x%x%x$') then
        return M.harmonize_color(fg, opts)
    end

    local source_readable = source_readable_foreground(fg, bg, opts)
    local anchored = palette_harmony_anchor(fg, bg, opts)
    if
        (contrast_ratio(anchored, bg) or 0)
        >= ((opts and (opts.min_contrast or opts.minimum_contrast)) or DEFAULT_MIN_CONTRAST)
    then
        local anchored_distance = color_identity_distance(fg, anchored)
        if not palette_candidate_preserves_identity(fg, anchored) then
            return source_readable
                or hue_preserving_foreground(fg, bg, opts)
                or hue_preserving_foreground(anchored, bg, opts)
        end
        if source_readable ~= nil then
            local source_distance = color_identity_distance(fg, source_readable)
            if anchored_distance > math.max(source_distance, palette_distance_tolerance(opts)) then
                return source_readable
            end
        end
        return anchored
    end

    return source_readable or hue_preserving_foreground(anchored, bg, opts) or readable_foreground(bg, opts)
end

--- @param bg string
--- @param opts? statuesque.ComposeOptions
--- @return string
function readable_foreground(bg, opts)
    opts = opts or {}
    local minimum = opts.min_contrast or opts.minimum_contrast or DEFAULT_MIN_CONTRAST
    local candidates = {
        opts.readable_foreground,
        opts.readable_dark or DEFAULT_READABLE_DARK,
        opts.readable_light or DEFAULT_READABLE_LIGHT,
        opts.hard_readable_dark or HARD_READABLE_DARK,
        opts.hard_readable_light or HARD_READABLE_LIGHT,
    }
    local best = candidates[1]
    local best_contrast = 0

    for _, candidate in ipairs(candidates) do
        if candidate ~= nil then
            local candidate_contrast = contrast_ratio(candidate, bg) or 0
            if candidate_contrast >= minimum then
                return candidate
            end
            if candidate_contrast > best_contrast then
                best = candidate
                best_contrast = candidate_contrast
            end
        end
    end

    return best
end

--- @param fg string
--- @param bg string
--- @param opts? statuesque.ComposeOptions
--- @return string?
function hue_preserving_foreground(fg, bg, opts)
    local candidate = semantic_repair_candidate(fg, bg, opts, nil)
    return candidate and candidate.color or nil
end

--- @class statuesque.SemanticRepairCandidate
--- @field color string
--- @field score number
--- @field luminance number
--- @field contrast number

--- @param opts? statuesque.ComposeOptions
--- @return string
local function semantic_palette_key(opts)
    if type(opts) == 'table' then
        local key = rawget(opts, '__statuesque_palette_key')
        if key ~= nil then
            return key
        end
    end
    return table.concat(resolve_palette(opts), ',')
end

--- @param fg string
--- @param bg string
--- @param opts? statuesque.ComposeOptions
--- @param direction? 'exact'|'light'|'dark'
--- @return string
local function semantic_candidate_cache_key(fg, bg, opts, direction)
    local minimum = opts and (opts.min_contrast or opts.minimum_contrast) or DEFAULT_MIN_CONTRAST
    return table.concat({
        fg,
        bg,
        direction or '',
        tostring(minimum),
        tostring(palette_distance_tolerance(opts)),
        editor_background(opts),
        semantic_palette_key(opts),
    }, '|')
end

--- @param fg string
--- @param bg string
--- @param opts? statuesque.ComposeOptions
--- @param direction? 'exact'|'light'|'dark'
--- @return statuesque.SemanticRepairCandidate?
function semantic_repair_candidate(fg, bg, opts, direction)
    opts = opts or {}
    direction = direction or preferred_direction_for_background(bg, opts)
    local cache_key = semantic_candidate_cache_key(fg, bg, opts, direction)
    if semantic_candidate_cache[cache_key] ~= nil then
        return semantic_candidate_cache[cache_key] ~= false and semantic_candidate_cache[cache_key] or nil
    end

    --- @param candidate statuesque.SemanticRepairCandidate?
    --- @return statuesque.SemanticRepairCandidate?
    local function finish(candidate)
        semantic_candidate_cache[cache_key] = candidate or false
        return candidate
    end

    local source_lch = rgb_to_oklch(fg)
    if source_lch == nil then
        return finish(nil)
    end

    local source_luminance = relative_luminance(fg) or 0.5
    local minimum = opts.min_contrast or opts.minimum_contrast or DEFAULT_MIN_CONTRAST
    local best
    local best_score = math.huge

    if direction == 'exact' then
        if (contrast_ratio(fg, bg) or 0) >= minimum then
            return finish({
                color = fg,
                score = 0,
                luminance = relative_luminance(fg) or 0.5,
                contrast = contrast_ratio(fg, bg) or 0,
            })
        end
    end

    --- @param candidate string
    --- @param source_penalty number
    --- @param palette_candidate? boolean
    local function consider_candidate(candidate, source_penalty, palette_candidate)
        local candidate_contrast = contrast_ratio(candidate, bg) or 0
        if candidate_contrast < minimum then
            return
        end
        if palette_candidate and not palette_candidate_preserves_identity(fg, candidate) then
            return
        end

        local candidate_lch = rgb_to_oklch(candidate)
        if candidate_lch == nil then
            return
        end

        if
            not palette_candidate
            and source_lch.chroma > OKLCH_CHROMA_EPSILON
            and candidate_lch.chroma < source_lch.chroma * OKLCH_MIN_SEMANTIC_CHROMA_RATIO
        then
            return
        end

        local candidate_luminance = relative_luminance(candidate) or 0.5
        if
            direction == 'light'
            and candidate_luminance < source_luminance
            and candidate_lch.lightness < source_lch.lightness
        then
            return
        end
        if
            direction == 'dark'
            and candidate_luminance > source_luminance
            and candidate_lch.lightness > source_lch.lightness
        then
            return
        end
        if direction == 'exact' and color_identity_distance(fg, candidate) > palette_distance_tolerance(opts) then
            return
        end

        local chroma_loss = math.max(0, source_lch.chroma - candidate_lch.chroma)
        local chroma_ratio = source_lch.chroma > 0 and math.min(candidate_lch.chroma / source_lch.chroma, 1) or 1
        local hue_penalty = 0
        if source_lch.chroma > OKLCH_CHROMA_EPSILON and candidate_lch.chroma > OKLCH_CHROMA_EPSILON then
            hue_penalty = hue_distance(source_lch.hue, candidate_lch.hue) / math.pi
        end
        local endpoint_penalty = math.max(0, candidate_lch.lightness - 0.9, 0.08 - candidate_lch.lightness)
        local identity_penalty = oklab_distance(fg, candidate) * 1.8
        local direction_lightness_penalty = 0
        if direction == 'dark' then
            direction_lightness_penalty = 1 - candidate_lch.lightness
        elseif direction == 'light' then
            direction_lightness_penalty = candidate_lch.lightness
        end
        local contrast_excess = math.max(0, candidate_contrast - minimum)
        local palette_bonus = palette_candidate and -0.18 or 0
        local semantic_chroma_bias = palette_candidate and 0.2 or 2.8
        local score = (direction_lightness_penalty * 2.0)
            + (chroma_loss * 3.5)
            + ((1 - chroma_ratio) * semantic_chroma_bias)
            + (hue_penalty * 3.5)
            + endpoint_penalty
            + identity_penalty
            + source_penalty
            + palette_bonus
            - (contrast_excess * 0.03)
        if score < best_score then
            best = {
                color = candidate,
                score = score,
                luminance = candidate_luminance,
                contrast = candidate_contrast,
            }
            best_score = score
        end
    end

    for _, candidate in ipairs(resolve_palette(opts)) do
        consider_candidate(candidate, 0.05, true)
    end

    if direction == 'exact' then
        return finish(best)
    end

    local start_lightness = math.floor(source_lch.lightness * 100 + 0.5)
    local lightness_start = direction == 'light' and start_lightness or 0
    local lightness_end = direction == 'light' and 100 or start_lightness

    for step = lightness_start, lightness_end do
        local candidate_lightness = step / 100
        if direction == 'dark' then
            candidate_lightness = (lightness_end - step) / 100
        end

        local minimum_chroma_step = source_lch.chroma > OKLCH_CHROMA_EPSILON and 55 or 0
        for chroma_step = 100, minimum_chroma_step, -5 do
            local candidate = oklch_to_hex(candidate_lightness, source_lch.chroma * (chroma_step / 100), source_lch.hue)
            if candidate ~= nil then
                consider_candidate(candidate, math.abs(candidate_lightness - source_lch.lightness), false)
            end
        end
    end

    return finish(best)
end

--- @class statuesque.SemanticRepairPair
--- @field fg string
--- @field bg string
--- @field preferred_direction 'dark'|'light'

--- @class statuesque.SemanticRepairPlan
--- @field direction 'exact'|'dark'|'light'
--- @field score number

--- @param opts? statuesque.ComposeOptions
--- @param pairs statuesque.SemanticRepairPair[]
--- @param direction 'exact'|'dark'|'light'
--- @return number
local function score_semantic_direction(opts, pairs, direction)
    local worst_contrast = math.huge
    local best_contrast = 0
    local total_contrast = 0
    local total_identity = 0
    local congruent = 0
    local missing = 0

    for _, pair in ipairs(pairs) do
        local candidate = semantic_repair_candidate(pair.fg, pair.bg, opts, direction)
        if candidate == nil then
            missing = missing + 1
        else
            local contrast = candidate.contrast or contrast_ratio(candidate.color, pair.bg) or 0
            worst_contrast = math.min(worst_contrast, contrast)
            best_contrast = math.max(best_contrast, contrast)
            total_contrast = total_contrast + contrast
            total_identity = total_identity + candidate.score
        end

        if direction == 'exact' or direction == pair.preferred_direction then
            congruent = congruent + 1
        end
    end

    local available = #pairs - missing
    if available == 0 then
        return -math.huge
    end

    local average_contrast = total_contrast / available
    local average_identity = total_identity / available
    local congruence = congruent / #pairs
    local coverage = available / #pairs

    if worst_contrast == math.huge then
        worst_contrast = 0
    end

    local exact_bonus = direction == 'exact' and missing == 0 and 6 or 0

    return exact_bonus
        + (coverage * 12)
        + (worst_contrast * 3)
        + (average_contrast * 1.25)
        + (best_contrast * 0.25)
        + (congruence * 2)
        - (average_identity * 0.35)
        - (missing * 8)
end

--- @param opts? statuesque.ComposeOptions
--- @return boolean
--- @param opts? statuesque.ComposeOptions
--- @param pairs statuesque.SemanticRepairPair[]
--- @return statuesque.SemanticRepairPlan?
local function choose_semantic_repair_plan(opts, pairs)
    if #pairs == 0 then
        return nil
    end

    local exact_score = 0
    local all_exact = true
    for _, pair in ipairs(pairs) do
        local candidate = semantic_repair_candidate(pair.fg, pair.bg, opts, 'exact')
        if candidate == nil then
            all_exact = false
            break
        end
        exact_score = exact_score + candidate.contrast
    end

    if all_exact then
        return {
            direction = 'exact',
            score = exact_score,
        }
    end

    local best_direction = 'exact'
    local best_score = -math.huge
    for _, direction in ipairs(SEMANTIC_REPAIR_DIRECTIONS) do
        local score = score_semantic_direction(opts, pairs, direction)
        if score > best_score then
            best_direction = direction
            best_score = score
        end
    end

    local plan = {
        direction = best_direction,
        score = best_score,
    }

    return plan
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
    readable.fg = M.match_palette_color(hl.fg, hl.bg, opts) or readable_foreground(hl.bg, opts)
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

--- @param group string
--- @return statuesque.HighlightSpec?
local function resolve_highlight_group(group)
    if vim == nil or vim.api == nil or vim.api.nvim_get_hl == nil then
        return nil
    end

    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group })
    if not ok or type(hl) ~= 'table' then
        return nil
    end

    return {
        fg = color_value(hl.fg),
        bg = color_value(hl.bg),
        sp = color_value(hl.sp),
        bold = hl.bold,
        italic = hl.italic,
        underline = hl.underline,
        undercurl = hl.undercurl,
        underdouble = hl.underdouble,
        underdotted = hl.underdotted,
        underdashed = hl.underdashed,
        strikethrough = hl.strikethrough,
        reverse = hl.reverse,
        nocombine = hl.nocombine,
    }
end

--- @param hl statuesque.Highlight?
--- @param inherited statuesque.HighlightSpec
--- @return statuesque.HighlightSpec
--- @return boolean has_explicit_foreground
--- @return boolean has_explicit_background
local function resolve_section_highlight(hl, inherited)
    local next_hl = type(hl) == 'string' and resolve_highlight_group(hl) or copy(hl)
    local has_explicit_foreground = type(next_hl) == 'table' and next_hl.fg ~= nil
    local has_explicit_background = type(next_hl) == 'table' and next_hl.bg ~= nil

    if type(next_hl) ~= 'table' or (vim.islist and vim.islist(next_hl)) then
        next_hl = {}
    end

    if next_hl.fg == nil then
        next_hl.fg = inherited.fg
    end
    if next_hl.bg == nil then
        next_hl.bg = inherited.bg
    end

    return next_hl, has_explicit_foreground, has_explicit_background
end

--- @param opts? statuesque.ComposeOptions
--- @param nodes statuesque.NormalizedNode[]
--- @param inherited statuesque.HighlightSpec
--- @param pairs statuesque.SemanticRepairPair[]
local function collect_semantic_repair_pairs(opts, nodes, inherited, pairs)
    for _, node in ipairs(nodes) do
        local node_hl, has_explicit_foreground = resolve_section_highlight(node.hl, inherited)
        if has_explicit_foreground and node_hl.fg ~= nil and node_hl.bg ~= nil then
            pairs[#pairs + 1] = {
                fg = node_hl.fg,
                bg = node_hl.bg,
                preferred_direction = preferred_direction_for_background(node_hl.bg, opts),
            }
        end

        if node.children ~= nil then
            collect_semantic_repair_pairs(opts, node.children, node_hl, pairs)
        end
    end
end

--- @param opts? statuesque.ComposeOptions
--- @param nodes statuesque.NormalizedNode[]
--- @param inherited statuesque.HighlightSpec
--- @return statuesque.SemanticRepairPlan?
local function semantic_repair_plan_for_nodes(opts, nodes, inherited)
    local pairs = {}
    collect_semantic_repair_pairs(opts, nodes, inherited, pairs)
    return choose_semantic_repair_plan(opts, pairs)
end

--- @class statuesque.SemanticForegroundSource
--- @field fg string

--- @param nodes statuesque.NormalizedNode[]
--- @param inherited statuesque.HighlightSpec
--- @param output statuesque.SemanticForegroundSource[]
local function collect_inherited_background_foregrounds(nodes, inherited, output)
    for _, node in ipairs(nodes) do
        local node_hl, has_explicit_foreground, has_explicit_background = resolve_section_highlight(node.hl, inherited)
        if has_explicit_foreground and not has_explicit_background and node_hl.fg ~= nil then
            output[#output + 1] = { fg = node_hl.fg }
        end

        if node.children ~= nil then
            collect_inherited_background_foregrounds(node.children, node_hl, output)
        end
    end
end

--- @param fg string
--- @param bg string
--- @param opts statuesque.ComposeOptions
--- @return boolean
local function semantic_source_is_readable(fg, bg, opts)
    local minimum = opts.min_contrast or opts.minimum_contrast or DEFAULT_SEMANTIC_MIN_CONTRAST
    return (contrast_ratio(fg, bg) or 0) >= minimum
end

--- @param level statuesque.HighlightSpec
--- @param base statuesque.HighlightSpec
--- @param sources statuesque.SemanticForegroundSource[]
--- @param opts statuesque.ComposeOptions
--- @return statuesque.HighlightSpec
local function semantic_section_level(level, base, sources, opts)
    if #sources < 2 or type(level.bg) ~= 'string' or type(base.bg) ~= 'string' or level.bg == base.bg then
        return level
    end

    local readable_opts = semantic_foreground_opts(opts)
    local best_level = level
    local best_score = -math.huge

    for step = 0, 20 do
        local mix = step / 20
        local bg = M.interpolate_color(level.bg, base.bg, mix)
        if bg ~= nil then
            local readable = 0
            local worst = math.huge
            local total = 0

            for _, source in ipairs(sources) do
                local source_contrast = contrast_ratio(source.fg, bg) or 0
                local repaired = semantic_repair_candidate(source.fg, bg, readable_opts, 'exact')
                local usable_contrast = repaired and repaired.contrast or source_contrast
                if semantic_source_is_readable(source.fg, bg, readable_opts) then
                    readable = readable + 1
                end
                worst = math.min(worst, usable_contrast)
                total = total + usable_contrast
            end

            local readable_ratio = readable / #sources
            local average = total / #sources
            local score = (readable_ratio * 30) + (worst * 4) + average - (mix * 0.35)
            if readable == #sources then
                return vim.tbl_deep_extend('force', level, { bg = bg })
            end
            if score > best_score then
                best_score = score
                best_level = vim.tbl_deep_extend('force', level, { bg = bg })
            end
        end
    end

    return best_level
end

--- @param opts? statuesque.ComposeOptions
--- @param hl statuesque.Highlight?
--- @param inherited statuesque.HighlightSpec
--- @param repair_plan? statuesque.SemanticRepairPlan
--- @return statuesque.HighlightSpec
local function inherit_section_highlight(opts, hl, inherited, repair_plan)
    local next_hl, has_explicit_foreground = resolve_section_highlight(hl, inherited)
    local readable_opts = opts

    if has_explicit_foreground and next_hl.fg ~= nil and next_hl.bg ~= nil then
        readable_opts = semantic_foreground_opts(opts)
        local source_fg = next_hl.fg
        local candidate = repair_plan
                and semantic_repair_candidate(next_hl.fg, next_hl.bg, readable_opts, repair_plan.direction)
            or nil
        if candidate ~= nil then
            next_hl.fg = candidate.color
            if candidate.color ~= source_fg and next_hl.bold == nil then
                next_hl.bold = true
            end
        else
            next_hl.fg = M.match_palette_color(next_hl.fg, next_hl.bg, readable_opts)
        end
    end

    return ensure_readable_hl(next_hl, readable_opts)
end

--- @param opts? statuesque.ComposeOptions
--- @param nodes statuesque.NormalizedNode[]
--- @param inherited statuesque.HighlightSpec
--- @return statuesque.NormalizedNode[]
local function inherit_section_backgrounds(opts, nodes, inherited)
    local next_nodes = {}
    local readable_opts = semantic_foreground_opts(opts)
    local repair_plan = semantic_repair_plan_for_nodes(readable_opts, nodes, inherited)

    for index, node in ipairs(nodes) do
        local next_node = copy(node)
        local node_hl = inherit_section_highlight(opts, next_node.hl, inherited, repair_plan)

        next_node.hl = node_hl

        if next_node.children ~= nil then
            next_node.children = inherit_section_backgrounds(opts, next_node.children, node_hl)
        end

        next_nodes[index] = next_node
    end

    return next_nodes
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
--- @param surface statuesque.Surface
--- @param opts statuesque.ComposeOptions
--- @return statuesque.HighlightSpec
local function effective_section_level(prepared, level, surface, opts)
    if prepared.custom_rendered then
        return level
    end

    local component = prepared.component
    if type(component) == 'table' and component.hl ~= nil then
        return level
    end

    local sources = {}
    collect_inherited_background_foregrounds(prepared.nodes, level, sources)
    return semantic_section_level(level, base_style(surface, opts), sources, opts)
end

--- @param prepared statuesque.PreparedComponent
--- @param level statuesque.HighlightSpec
--- @param level_index integer
--- @param surface statuesque.Surface
--- @param opts statuesque.ComposeOptions
--- @return statuesque.NormalizedNode
local function section_node(prepared, level, level_index, surface, opts)
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
        children = inherit_section_backgrounds(opts, prepared.nodes, level),
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
        local level = effective_section_level(prepared_component, levels[index], surface, opts)
        if
            not prepared_component.custom_rendered and not (prepared[index - 1] and prepared[index - 1].custom_rendered)
        then
            nodes[#nodes + 1] =
                separator_node('segment-leading-separator', leading_separator, base_hl, level, defaults, 'right', {
                    after = separator_padding,
                })
        end
        nodes[#nodes + 1] = section_node(prepared_component, level, index, surface, opts)
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
        local level = effective_section_level(prepared_component, levels[index], surface, opts)
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
        nodes[#nodes + 1] = section_node(prepared_component, level, index, surface, opts)
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
        local level = effective_section_level(prepared_component, levels[index], surface, opts)
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

        nodes[#nodes + 1] = section_node(prepared_component, level, index, surface, opts)
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

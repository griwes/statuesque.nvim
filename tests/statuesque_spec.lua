local statuesque = require('statuesque')
local style = require('statuesque.style')

local function assert_equal(actual, expected)
    assert(actual == expected, ('expected %q, got %q'):format(tostring(expected), tostring(actual)))
end

local function assert_contains(actual, expected)
    assert(tostring(actual):find(expected, 1, true), ('expected %q to contain %q'):format(tostring(actual), expected))
end

local function count_occurrences(actual, needle)
    local count = 0
    local start = 1
    while true do
        local found = tostring(actual):find(needle, start, true)
        if found == nil then
            return count
        end
        count = count + 1
        start = found + #needle
    end
end

local function table_size(value)
    local count = 0
    for _ in pairs(value) do
        count = count + 1
    end
    return count
end

local function strip_vim_statusline(actual)
    return tostring(actual):gsub('%%#[^#]-#', ''):gsub('%%%*', '')
end

local function highlight_hex(value)
    if value == nil then
        return nil
    end

    return ('#%06x'):format(value)
end

local function incline_chunk_text(chunk)
    if type(chunk) == 'table' then
        return chunk[1]
    end
    return chunk
end

local function rendered_highlight_with_fg(rendered, prefix, fg)
    for name in tostring(rendered):gmatch('%%#([^#]-)#') do
        if name:sub(1, #prefix) == prefix then
            local hl = vim.api.nvim_get_hl(0, { name = name })
            if highlight_hex(hl.fg) == fg then
                return {
                    name = name,
                    fg = highlight_hex(hl.fg),
                    bg = highlight_hex(hl.bg),
                }
            end
        end
    end

    return nil
end

local function assert_ends_with(actual, expected)
    actual = tostring(actual)
    assert_equal(actual:sub(-#expected), expected)
end

local function assert_separator(node, glyph)
    assert_equal(node.children[1].text, ' ')
    assert_equal(node.children[2].text, glyph)
    assert_equal(node.children[3].text, ' ')
end

local function assert_unpadded_separator(node, glyph)
    assert_equal(#node.children, 1)
    assert_equal(node.children[1].text, glyph)
end

local function rgb(hex)
    local value = hex:match('^#?(%x%x%x%x%x%x)$')
    return tonumber(value:sub(1, 2), 16), tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16)
end

local function channel_spread(hex)
    local red, green, blue = rgb(hex)
    return math.max(red, green, blue) - math.min(red, green, blue)
end

local function relative_channel(value)
    value = value / 255
    if value <= 0.03928 then
        return value / 12.92
    end
    return ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(hex)
    local red, green, blue = rgb(hex)
    return 0.2126 * relative_channel(red) + 0.7152 * relative_channel(green) + 0.0722 * relative_channel(blue)
end

local function contrast(left, right)
    local left_luminance = luminance(left)
    local right_luminance = luminance(right)
    local lighter = math.max(left_luminance, right_luminance)
    local darker = math.min(left_luminance, right_luminance)
    return (lighter + 0.05) / (darker + 0.05)
end

local function assert_gapped_leading_separator(node, glyph)
    assert_equal(#node.children, 2)
    assert_equal(node.children[1].text, glyph)
    assert_equal(node.children[2].text, ' ')
end

local function assert_gapped_trailing_separator(node, glyph)
    assert_equal(#node.children, 2)
    assert_equal(node.children[1].text, ' ')
    assert_equal(node.children[2].text, glyph)
end

local function with_runtimepath(prefix, body)
    local previous_runtimepath = vim.o.runtimepath
    vim.opt.runtimepath:prepend(prefix)
    local results = { pcall(body) }
    vim.o.runtimepath = previous_runtimepath

    if not results[1] then
        error(results[2])
    end

    return unpack(results, 2)
end

describe('statuesque render spec', function()
    it('normalizes nested strings and segment children', function()
        local normalized = statuesque.normalize({
            {
                id = 'domain:alpha',
                role = 'domain',
                hl = 'StatuesqueDomain',
                'Alpha',
                children = {
                    { text = ' *', role = 'status' },
                },
            },
            ' ',
            { text = 'Beta', max_width = 3 },
        })

        assert_equal(#normalized, 3)
        assert_equal(normalized[1].id, 'domain:alpha')
        assert_equal(normalized[1].children[1].text, 'Alpha')
        assert_equal(normalized[1].children[2].text, ' *')
        assert_equal(normalized[2].text, ' ')
        assert_equal(normalized[3].text, 'Beta')
    end)

    it('renders debug snapshots without executable function values', function()
        local debug = statuesque.render({
            {
                text = 'actions',
                on_click = function() end,
                on_hover = function() end,
            },
        }, 'debug')

        assert_equal(debug[1].on_click, '<function>')
        assert_equal(debug[1].on_hover, '<function>')
    end)

    it('renders plain text with truncation policies', function()
        assert_equal(statuesque.render({ text = 'abcdefgh', max_width = 5 }, 'text'), 'ab...')
        assert_equal(statuesque.render({ text = 'abcdefgh', max_width = 5, truncate = 'left' }, 'text'), '...gh')
        assert_equal(statuesque.render({ text = 'abcdefgh', max_width = 5, truncate = 'middle' }, 'text'), 'a...h')
        assert_equal(statuesque.render({ text = 'abcdefgh', max_width = 5, truncate = 'hide' }, 'text'), '')
    end)

    it('applies max width in display cells', function()
        assert_equal(statuesque.render({ text = '界界界', max_width = 5 }, 'text'), '界...')
        assert_equal(statuesque.render({ text = '界界界', max_width = 5, truncate = 'left' }, 'text'), '...界')
        assert_equal(statuesque.render({ text = '界界', max_width = 3 }, 'text'), '界')
        assert(vim.fn.strdisplaywidth(statuesque.render({ text = 'a界bc界', max_width = 6 }, 'text')) <= 6)
    end)

    it('evaluates top-level and embedded function render specs with context', function()
        local rendered = statuesque.render(
            {
                'mode:',
                function(context)
                    return context.mode
                end,
                {
                    role = 'dynamic-wrapper',
                    function(context)
                        return {
                            text = ':' .. context.domain,
                        }
                    end,
                },
            },
            'text',
            {
                mode = 'insert',
                domain = 'Alpha',
            }
        )

        assert_equal(rendered, 'mode:insert:Alpha')
    end)

    it('caches function-backed render fragments until explicit invalidation', function()
        local calls = 0
        local truncate_calls = 0
        local spec = require('statuesque.spec')
        local original_truncate_text = spec.truncate_text
        local dynamic = {
            id = 'cached-dynamic',
            cache = { key = 'cached-dynamic' },
            render = function(context)
                calls = calls + 1
                return context.value
            end,
        }

        spec.truncate_text = function(text, node)
            if node._statuesque_cache_key == 'cached-dynamic' then
                truncate_calls = truncate_calls + 1
            end
            return original_truncate_text(text, node)
        end

        assert_equal(statuesque.render({ 'value=', dynamic }, 'text', { value = 'one' }), 'value=one')
        assert_equal(statuesque.render({ 'value=', dynamic }, 'text', { value = 'two' }), 'value=one')
        assert_equal(calls, 1)
        assert_equal(truncate_calls, 1)

        statuesque.invalidate('cached-dynamic')

        assert_equal(statuesque.render({ 'value=', dynamic }, 'text', { value = 'two' }), 'value=two')
        assert_equal(calls, 2)
        assert_equal(truncate_calls, 2)
        spec.truncate_text = original_truncate_text
    end)

    it('keeps anonymous cache=true components isolated by table identity', function()
        local first = {
            cache = true,
            render = function()
                return 'first'
            end,
        }
        local second = {
            cache = true,
            render = function()
                return 'second'
            end,
        }

        assert_equal(statuesque.render({ first }, 'text'), 'first')
        assert_equal(statuesque.render({ second }, 'text'), 'second')
    end)

    it('keeps renderer cache variants separate by render options', function()
        local cached_separator = {
            id = 'cached-separator',
            cache = { key = 'cached-separator' },
            render = function()
                return { separator = 'section' }
            end,
        }

        assert_equal(
            incline_chunk_text(statuesque.render({ cached_separator }, 'incline', { side = 'left' })[1]),
            '  '
        )
        assert_equal(
            incline_chunk_text(statuesque.render({ cached_separator }, 'incline', { side = 'right' })[1]),
            '  '
        )
    end)

    it('keeps cached winbar fragments separate per window and buffer', function()
        local calls = 0
        local cached = {
            id = 'cached-window-context',
            cache = { key = 'cached-window-context' },
            render = function(context)
                calls = calls + 1
                return ('%s:%s'):format(context.winid, context.bufnr)
            end,
        }

        assert_equal(statuesque.render({ cached }, 'winbar', { winid = 101, bufnr = 201 }), '101:201')
        assert_equal(statuesque.render({ cached }, 'winbar', { winid = 102, bufnr = 202 }), '102:202')
        assert_equal(statuesque.render({ cached }, 'winbar', { winid = 101, bufnr = 201 }), '101:201')
        assert_equal(calls, 2)

        statuesque.invalidate('cached-window-context')
        assert_equal(statuesque.render({ cached }, 'winbar', { winid = 101, bufnr = 201 }), '101:201')
        assert_equal(calls, 3)
    end)

    it('keeps cached incline fragments separate per window and buffer', function()
        local calls = 0
        local cached = {
            id = 'cached-incline-window-context',
            cache = { key = 'cached-incline-window-context' },
            render = function(context)
                calls = calls + 1
                return {
                    text = ('%s:%s'):format(context.winid, context.bufnr),
                }
            end,
        }

        assert_equal(
            incline_chunk_text(statuesque.render({ cached }, 'incline', { winid = 301, bufnr = 401 })[1]),
            '301:401'
        )
        assert_equal(
            incline_chunk_text(statuesque.render({ cached }, 'incline', { winid = 302, bufnr = 402 })[1]),
            '302:402'
        )
        assert_equal(
            incline_chunk_text(statuesque.render({ cached }, 'incline', { winid = 301, bufnr = 401 })[1]),
            '301:401'
        )
        assert_equal(calls, 2)
    end)

    it('keeps cached statusline fragments global even when window context is provided', function()
        local calls = 0
        local cached = {
            id = 'cached-statusline-global-context',
            cache = { key = 'cached-statusline-global-context' },
            render = function(context)
                calls = calls + 1
                return ('%s:%s'):format(context.winid, context.bufnr)
            end,
        }

        assert_contains(statuesque.render({ cached }, 'statusline', { winid = 501, bufnr = 601 }), '501:601')
        assert_contains(statuesque.render({ cached }, 'statusline', { winid = 502, bufnr = 602 }), '501:601')
        assert_equal(calls, 1)
    end)

    it('keeps cached separator render variants separate by backend defaults', function()
        local cached_separator = {
            id = 'cached-separator-defaults',
            cache = { key = 'cached-separator-defaults' },
            render = function()
                return { separator = 'section' }
            end,
        }

        assert_equal(
            statuesque.render({ cached_separator }, 'text', {
                backend_defaults = {
                    left_separator = 'A',
                    separator_padding = '',
                },
            }),
            'A'
        )
        assert_equal(
            statuesque.render({ cached_separator }, 'text', {
                backend_defaults = {
                    left_separator = 'B',
                    separator_padding = '',
                },
            }),
            'B'
        )
    end)

    it('encodes custom separator defaults without variant key collisions', function()
        local cached_separator = {
            id = 'cached-separator-default-collisions',
            cache = { key = 'cached-separator-default-collisions' },
            render = function()
                return { separator = 'section' }
            end,
        }

        assert_equal(
            statuesque.render({ cached_separator }, 'text', {
                backend_defaults = {
                    left_separator = 'a,b',
                    right_separator = 'c',
                    separator_padding = '',
                },
            }),
            'a,b'
        )
        assert_equal(
            statuesque.render({ cached_separator }, 'text', {
                backend_defaults = {
                    left_separator = 'a',
                    right_separator = 'b,c',
                    separator_padding = '',
                },
            }),
            'a'
        )
    end)

    it('keeps cached separator variants separate by backend default side', function()
        local cached_separator = {
            id = 'cached-separator-default-side',
            cache = { key = 'cached-separator-default-side' },
            render = function()
                return { separator = 'section' }
            end,
        }

        assert_equal(
            incline_chunk_text(statuesque.render({ cached_separator }, 'incline', {
                backend_defaults = {
                    side = 'left',
                    left_separator = 'L',
                    right_separator = 'R',
                    separator_padding = '',
                },
            })[1]),
            'L'
        )
        assert_equal(
            incline_chunk_text(statuesque.render({ cached_separator }, 'incline', {
                backend_defaults = {
                    side = 'right',
                    left_separator = 'L',
                    right_separator = 'R',
                    separator_padding = '',
                },
            })[1]),
            'R'
        )
    end)

    it('keeps Vim inline-highlight cache variants separate by prefix', function()
        local cached_highlight = {
            id = 'cached-highlight',
            cache = { key = 'cached-highlight' },
            render = function()
                return {
                    text = 'hot',
                    hl = { fg = '#ffffff', bg = '#000000' },
                }
            end,
        }

        assert(statuesque
            .render({ cached_highlight }, 'statusline', {
                inline_highlight_prefix = 'StatuesqueFirst',
            })
            :find('StatuesqueFirst1', 1, true))
        assert(statuesque
            .render({ cached_highlight }, 'statusline', {
                inline_highlight_prefix = 'StatuesqueSecond',
            })
            :find('StatuesqueSecond1', 1, true))
    end)

    it('reserves inline highlight indices for cached Vim fragments', function()
        local cached_highlight = {
            id = 'cached-highlight-index',
            cache = { key = 'cached-highlight-index' },
            render = function()
                return {
                    text = 'hot',
                    hl = { fg = '#ffffff', bg = '#000000' },
                }
            end,
        }
        local trailing_highlight = {
            text = 'tail',
            hl = { fg = '#000000', bg = '#ffffff' },
        }

        statuesque.render({ cached_highlight, trailing_highlight }, 'statusline', {
            inline_highlight_prefix = 'StatuesqueCachedIndex',
        })
        local rendered = statuesque.render({ cached_highlight, trailing_highlight }, 'statusline', {
            inline_highlight_prefix = 'StatuesqueCachedIndex',
        })

        assert(rendered:find('StatuesqueCachedIndex1', 1, true), rendered)
        assert(rendered:find('StatuesqueCachedIndex2', 1, true), rendered)
    end)

    it('reapplies inline highlights when Vim render fragments come from cache', function()
        local cached_highlight = {
            id = 'cached-highlight-reapply',
            cache = { key = 'cached-highlight-reapply' },
            render = function()
                return {
                    text = 'hot',
                    hl = { fg = '#112233', bg = '#445566' },
                }
            end,
        }

        statuesque.render({ cached_highlight }, 'statusline', {
            inline_highlight_prefix = 'StatuesqueCachedReapply',
        })
        vim.api.nvim_set_hl(0, 'StatuesqueCachedReapply1', { fg = '#ffffff', bg = '#000000' })
        statuesque.render({ cached_highlight }, 'statusline', {
            inline_highlight_prefix = 'StatuesqueCachedReapply',
        })

        local hl = vim.api.nvim_get_hl(0, { name = 'StatuesqueCachedReapply1' })
        assert_equal(('#%06x'):format(hl.fg), '#112233')
        assert_equal(('#%06x'):format(hl.bg), '#445566')
    end)

    it('keeps internal render metadata out of Vim inline highlight definitions', function()
        local ok, rendered = pcall(
            statuesque.render,
            {
                {
                    text = 'safe',
                    hl = {
                        fg = '#112233',
                        bg = '#445566',
                        __statuesque_dynamic_index = 9,
                    },
                },
            },
            'statusline',
            {
                inline_highlight_prefix = 'StatuesqueMetadataFilter',
            }
        )

        assert(ok, rendered)
        assert_contains(rendered, 'StatuesqueMetadataFilter1')

        local hl = vim.api.nvim_get_hl(0, { name = 'StatuesqueMetadataFilter1' })
        assert_equal(('#%06x'):format(hl.fg), '#112233')
        assert_equal(('#%06x'):format(hl.bg), '#445566')
    end)

    it('renders publisher components and refreshes them through published updates', function()
        local notify
        local value = 'cold'
        local publisher = {
            statuesque_component = true,
            cache = { key = 'publisher-demo' },
            render = function()
                return value
            end,
            subscribe = function(_, callback)
                notify = callback
            end,
        }

        assert_equal(statuesque.render({ publisher }, 'text'), 'cold')
        value = 'hot'
        assert_equal(statuesque.render({ publisher }, 'text'), 'cold')
        notify()
        assert_equal(statuesque.render({ publisher }, 'text'), 'hot')
    end)

    it('keeps no-cache publisher updates from invalidating unrelated caches', function()
        local notify
        local cached_calls = 0
        local cached = {
            cache = { key = 'publisher-unrelated-cache' },
            render = function()
                cached_calls = cached_calls + 1
                return ('cached-%d'):format(cached_calls)
            end,
        }
        local publisher = {
            statuesque_component = true,
            render = function()
                return 'live'
            end,
            subscribe = function(_, callback)
                notify = callback
            end,
        }

        assert_equal(statuesque.render({ cached, publisher }, 'text'), 'cached-1live')
        notify()
        assert_equal(statuesque.render({ cached, publisher }, 'text'), 'cached-1live')
    end)

    it('invalidates every scoped cache owned by a shared publisher', function()
        local notify
        local values = {
            [11] = 'first-old',
            [22] = 'second-old',
        }
        local publisher = {
            statuesque_component = true,
            cache = {
                key = 'publisher-window-cache',
                cache_mode = 'window',
            },
            render = function(_, context)
                return values[context.winid]
            end,
            subscribe = function(_, callback)
                notify = callback
            end,
        }

        assert_equal(statuesque.render({ publisher }, 'text', { winid = 11 }), 'first-old')
        assert_equal(statuesque.render({ publisher }, 'text', { winid = 22 }), 'second-old')

        values[11] = 'first-new'
        values[22] = 'second-new'
        notify()

        assert_equal(statuesque.render({ publisher }, 'text', { winid = 11 }), 'first-new')
        assert_equal(statuesque.render({ publisher }, 'text', { winid = 22 }), 'second-new')
    end)

    it('keeps live publisher callbacks strong without retaining dead publishers', function()
        local publisher_module = require('statuesque.publisher')
        local notify
        local updates = 0
        local component = {
            statuesque_component = true,
            render = function()
                return 'live'
            end,
            subscribe = function(_, callback)
                notify = callback
            end,
        }
        local weak_component = setmetatable({ component }, { __mode = 'v' })

        do
            local context = {
                on_update = function()
                    updates = updates + 1
                end,
            }
            assert_equal(statuesque.render({ component }, 'text', context), 'live')
        end

        collectgarbage('collect')
        collectgarbage('collect')
        notify()
        assert_equal(updates, 1)
        assert(publisher_module._subscriptions[component] ~= nil)

        component = nil
        collectgarbage('collect')
        collectgarbage('collect')
        assert_equal(weak_component[1], nil)
        notify()
        assert_equal(updates, 1)
    end)

    it('keeps the mode widget label reactive across redraws without keymaps', function()
        local mode_widget = require('statuesque.widgets.mode')()
        local original_mode_name = style.mode_name
        local ok, err = pcall(function()
            style.mode_name = function()
                return 'replace'
            end
            assert_equal(statuesque.render({ mode_widget }, 'text'), 'REPLACE')

            style.mode_name = function()
                return 'normal'
            end
            assert_equal(statuesque.render({ mode_widget }, 'text'), 'NORMAL')

            local back = vim.fn.maparg('<C-o>', 'n', false, true)
            local forward = vim.fn.maparg('<C-i>', 'n', false, true)

            assert(back.callback == nil, 'mode widget must not install <C-o>')
            assert(forward.callback == nil, 'mode widget must not install <C-i>')
        end)

        style.mode_name = original_mode_name
        if not ok then
            error(err)
        end
    end)

    it('resolves runtimepath widget references and optional missing widgets', function()
        assert_equal(statuesque.render({ name = 'missing_widget', optional = true }, 'text'), '')

        with_runtimepath('tests/fixtures/widget-module', function()
            package.loaded['statuesque.widgets.git_repo'] = nil
            local rendered = statuesque.render({
                name = 'git_repo',
                opts = {
                    icon = 'G',
                },
            }, 'text')
            package.loaded['statuesque.widgets.git_repo'] = nil

            assert_equal(rendered, 'G external-repo')
        end)
    end)

    it('keeps widget text unescaped before Vim target rendering', function()
        vim.cmd('enew!')
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
            'one',
            'two',
            'three',
            'four',
        })
        vim.api.nvim_win_set_cursor(0, { 2, 0 })

        local widget = require('statuesque.widgets.progress')()
        local spec = widget()

        assert_equal(spec.text, '50%')
        assert_contains(statuesque.render(spec, 'statusline'), '50%%')
    end)

    it('composes section-style bars with interpolated styles and explicit separators', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                { text = 'beta' },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = 'N',
                mode_style = false,
                palette = false,
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'sigil')
        assert_equal(debug[1].text, ' N ')
        assert_equal(debug[1].hl.bg, '#ff9e64')
        assert_equal(debug[2].role, 'separator')
        assert_separator(debug[2], '')
        assert_equal(debug[3].children[1].text, 'alpha')
        assert_equal(debug[5].children[1].text, 'beta')
        assert_equal(debug[3].hl.bg, '#ffffff')
        assert_equal(debug[4].children[1].hl.bg, '#ffffff')
        assert_equal(debug[4].children[2].hl.fg, '#ffffff')
        assert_equal(debug[4].children[2].hl.bg, '#0b0b0b')
        assert_equal(debug[4].children[3].hl.bg, '#0b0b0b')
        assert_equal(debug[5].hl.bg, '#0b0b0b')

        assert_equal(statuesque.render({ { separator = 'inner' } }, 'text'), '  ')
    end)

    it('keeps section backgrounds under child foreground highlights', function()
        vim.api.nvim_set_hl(0, 'StatuesqueFgOnlyChild', {
            fg = '#112233',
        })

        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'icon', hl = 'StatuesqueFgOnlyChild' },
                    { text = ' filetype' },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                palette = false,
                semantic_min_contrast = 4.5,
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[1].children[1].hl.fg, '#112233')
        assert_equal(debug[1].children[1].hl.bg, '#ffffff')
        assert_equal(debug[1].children[2].hl.bg, '#ffffff')
    end)

    it('keeps child foreground-only highlights readable after inheriting section backgrounds', function()
        vim.api.nvim_set_hl(0, 'StatuesqueUnreadableFgOnlyChild', {
            fg = '#fefefe',
        })

        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'icon', hl = 'StatuesqueUnreadableFgOnlyChild' },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                palette = false,
                semantic_min_contrast = 4.5,
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[1].children[1].hl.bg, '#ffffff')
        assert(debug[1].children[1].hl.fg ~= '#fefefe')
    end)

    it('preserves foreground hue when repairing inherited section contrast', function()
        vim.api.nvim_set_hl(0, 'StatuesqueWarmFgOnlyChild', {
            fg = '#f8c97a',
        })

        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'warm', hl = 'StatuesqueWarmFgOnlyChild' },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                palette = false,
                semantic_min_contrast = 4.5,
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )
        local repaired = debug[1].children[1].hl.fg
        local red, green, blue = rgb(repaired)

        assert(contrast(repaired, '#ffffff') >= 4.5, repaired)
        assert(repaired ~= '#1a1b26', repaired)
        assert(repaired ~= '#000000', repaired)
        assert(red > blue, repaired)
        assert(green > blue, repaired)
    end)

    it('can compose gapped section islands against the base bar style', function()
        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'alpha' },
                    { separator = 'inner' },
                    { text = 'one' },
                },
                { text = 'beta' },
            }, {
                surface = 'statusline',
                sigil = 'N',
                mode_style = false,
                base = { fg = '#eeeeee', bg = '#111111' },
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'sigil')
        assert_equal(debug[2].role, 'base-separator')
        assert_gapped_trailing_separator(debug[2], '')
        assert_equal(debug[2].children[2].hl.fg, '#ff9e64')
        assert_equal(debug[2].children[2].hl.bg, '#111111')
        assert_equal(debug[3].role, 'segment-leading-separator')
        assert_gapped_leading_separator(debug[3], '')
        assert_equal(debug[3].children[1].hl.fg, '#ffffff')
        assert_equal(debug[3].children[1].hl.bg, '#111111')
        assert_equal(debug[3].children[2].hl.bg, '#ffffff')
        assert_equal(debug[4].children[1].text, 'alpha')
        assert_equal(debug[4].children[2].separator, 'inner')
        assert_equal(debug[5].role, 'segment-trailing-separator')
        assert_gapped_trailing_separator(debug[5], '')
        assert_equal(debug[5].children[1].hl.bg, '#ffffff')
        assert_equal(debug[5].children[2].hl.fg, '#ffffff')
        assert_equal(debug[5].children[2].hl.bg, '#111111')
        assert_equal(debug[6].role, 'segment-leading-separator')
        assert_gapped_leading_separator(debug[6], '')
        assert_equal(debug[7].children[1].text, 'beta')
        assert_equal(debug[8].role, 'segment-trailing-separator')
        assert_equal(debug[9].role, 'right-edge-padding')
        assert_equal(debug[9].hl.bg, '#111111')
    end)

    it('lets gapped section islands opt into gap padding separately', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                { text = 'beta' },
            }, {
                surface = 'statusline',
                gap_padding = ' ',
                sigil = '',
            }),
            'debug'
        )

        assert_gapped_leading_separator(debug[1], '')
        assert_equal(debug[4].role, 'segment-gap')
        assert_equal(debug[4].text, ' ')
        assert_equal(debug[4].hl.bg, '#1f2335')
    end)

    it('passes fully custom-rendered components without generated section chrome', function()
        local debug = statuesque.render(
            statuesque.compose({
                {
                    role = 'custom-tabs',
                    custom_rendered = true,
                    children = {
                        { text = 'tab', hl = 'TabulatureActive1' },
                    },
                },
            }, {
                surface = 'tabline',
                sigil = '𝄞',
            }),
            'debug'
        )

        assert_equal(#debug, 4)
        assert_equal(debug[1].role, 'sigil')
        assert_equal(debug[1].text, ' 𝄞 ')
        assert_equal(debug[2].role, 'base-separator')
        assert_gapped_trailing_separator(debug[2], '')
        assert_equal(debug[3].role, 'custom-tabs')
        assert_equal(debug[4].role, 'right-edge-padding')
        assert_equal(statuesque.render(debug, 'text'), ' 𝄞  tab ')
    end)

    it('keeps capsule tabline sigils visually separated from custom-rendered content', function()
        local debug = statuesque.render(
            statuesque.compose({
                {
                    role = 'custom-tabs',
                    custom_rendered = true,
                    children = {
                        { text = 'tab', hl = 'TabulatureActive1' },
                    },
                },
            }, {
                surface = 'tabline',
                sigil = '𝄞',
                style = 'capsule',
            }),
            'debug'
        )

        assert_equal(debug[2].role, 'base-separator')
        assert_unpadded_separator(debug[2], '')
        assert_equal(statuesque.render(debug, 'text'), ' 𝄞 tab ')
    end)

    it('lets custom-rendered components suppress adjacent layout separators', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                {
                    role = 'custom-tabs',
                    custom_rendered = true,
                    children = {
                        { text = 'beta' },
                    },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
            }),
            'debug'
        )

        assert_equal(debug[1].children[1].text, 'alpha')
        assert_equal(debug[2].role, 'custom-tabs')
        assert_equal(statuesque.render(debug, 'text'), 'alphabeta ')
    end)

    it('preserves the custom-rendered marker on single normalized nodes', function()
        local debug = statuesque.render(
            statuesque.compose({
                {
                    custom_rendered = true,
                    children = {
                        { text = 'alpha' },
                    },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
            }),
            'debug'
        )

        assert_equal(#debug, 2)
        assert_equal(debug[1].custom_rendered, true)
        assert_equal(debug[1].children[1].text, 'alpha')
        assert_equal(debug[2].role, 'right-edge-padding')
    end)

    it('does not emit gapped section separators across custom-rendered component boundaries', function()
        local rendered = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                {
                    role = 'custom-tabs',
                    custom_rendered = true,
                    children = {
                        { text = 'beta' },
                    },
                },
                { text = 'gamma' },
            }, {
                surface = 'tabline',
                sigil = '',
            }),
            'text'
        )

        assert_contains(rendered, 'alpha beta')
        assert_contains(rendered, 'betagamma')
        assert(not rendered:find('beta ', 1, true), rendered)
    end)

    it('mirrors gapped section islands on the right side', function()
        local debug = statuesque.render(
            statuesque.compose({
                right = {
                    { text = 'omega' },
                    { text = 'tail' },
                },
            }, {
                surface = 'statusline',
                sigil = '',
                mode_style = false,
                base = { fg = '#eeeeee', bg = '#111111' },
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[1].align, 'right')
        assert_equal(debug[2].role, 'segment-leading-separator')
        assert_gapped_leading_separator(debug[2], '')
        assert_equal(debug[3].children[1].text, 'omega')
        assert_equal(debug[4].role, 'segment-trailing-separator')
        assert_gapped_trailing_separator(debug[4], '')
        assert_equal(debug[5].role, 'segment-leading-separator')
        assert_gapped_leading_separator(debug[5], '')
        assert_equal(debug[6].children[1].text, 'tail')
        assert_equal(debug[7].role, 'right-edge-padding')
        assert_equal(debug[7].hl.bg, '#ffffff')
        assert_equal(debug[2].children[1].hl.fg, debug[3].hl.bg)
        assert_equal(debug[2].children[1].hl.bg, '#111111')
        assert_equal(debug[4].children[2].hl.fg, debug[3].hl.bg)
        assert_equal(debug[4].children[2].hl.bg, '#111111')
        assert_equal(debug[5].children[1].hl.fg, debug[6].hl.bg)
        assert_equal(debug[5].children[1].hl.bg, '#111111')
    end)

    it('puts the sigil at the outer edge for right-sided single-surface composition', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'omega' },
            }, {
                surface = 'incline',
                side = 'right',
                sigil = 'S',
                mode_style = false,
                base = { fg = '#eeeeee', bg = '#111111' },
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'segment-leading-separator')
        assert_equal(debug[2].children[1].text, 'omega')
        assert_equal(debug[3].role, 'sigil-trailing-separator')
        assert_equal(debug[4].role, 'sigil-leading-separator')
        assert_equal(debug[#debug].role, 'sigil')
        assert_equal(debug[#debug].text, ' S  ')
    end)

    it('uses diagonal reverse separators for gapped tabline segment entry', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
            }, {
                surface = 'tabline',
                sigil = '',
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'segment-leading-separator')
        assert_gapped_leading_separator(debug[1], '')
        assert_equal(debug[2].children[1].text, 'alpha')
        assert_equal(debug[3].role, 'segment-trailing-separator')
        assert_gapped_trailing_separator(debug[3], '')
    end)

    it('applies the capsule style through a succinct style option', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                { text = 'beta' },
            }, {
                surface = 'statusline',
                sigil = '',
                style = 'capsule',
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'segment-leading-separator')
        assert_unpadded_separator(debug[1], '')
        assert_equal(debug[2].children[1].text, 'alpha')
        assert_equal(debug[3].role, 'segment-trailing-separator')
        assert_unpadded_separator(debug[3], '')
        assert_equal(debug[4].role, 'segment-gap')
        assert_equal(debug[4].text, ' ')
        assert_equal(debug[5].role, 'segment-leading-separator')
        assert_unpadded_separator(debug[5], '')
        assert_equal(debug[6].children[1].text, 'beta')
        assert_equal(debug[7].role, 'segment-trailing-separator')
        assert_unpadded_separator(debug[7], '')
    end)

    it('keeps a base-styled gap between a capsule sigil and the first segment', function()
        local composed = statuesque.compose({
            { text = 'NORMAL' },
        }, {
            surface = 'statusline',
            sigil = '',
            style = 'capsule',
        })
        local debug = statuesque.render(composed, 'debug')
        local rendered = statuesque.render(composed, 'text')

        assert_contains(rendered, '   NORMAL')
        assert(not rendered:find('', 1, true), rendered)
        assert_equal(debug[3].role, 'segment-gap')
        assert_equal(debug[3].text, ' ')
        assert_equal(debug[3].hl.bg, debug[2].hl.bg)
    end)

    it('renders right-side capsule sections with symmetric separators and base gaps', function()
        local composed = statuesque.compose({
            right = {
                { text = 'utf-8 unix' },
                { text = '1:1' },
                { text = 'Top' },
            },
        }, {
            surface = 'statusline',
            sigil = '',
            style = 'capsule',
        })
        local debug = statuesque.render(composed, 'debug')
        local rendered = statuesque.render(composed, 'text')

        assert_contains(rendered, 'utf-8 unix 1:1 Top')
        assert_ends_with(rendered, 'Top ')
        assert(not rendered:find(' utf%-8 unix ', 1, false), rendered)
        assert(not rendered:find('', 1, true), rendered)
        assert(not rendered:find(' 1:1 ', 1, true), rendered)
        assert_equal(debug[2].children[1].text, '')
        assert_equal(debug[2].children[1].hl.fg, debug[3].hl.bg)
        assert_equal(debug[2].children[1].hl.bg, debug[5].hl.bg)
        assert_equal(debug[4].children[1].text, '')
        assert_equal(debug[4].children[1].hl.fg, debug[3].hl.bg)
        assert_equal(debug[4].children[1].hl.bg, debug[5].hl.bg)
        assert_equal(debug[6].children[1].text, '')
        assert_equal(debug[6].children[1].hl.fg, debug[7].hl.bg)
        assert_equal(debug[6].children[1].hl.bg, debug[5].hl.bg)
        assert_equal(debug[8].children[1].text, '')
        assert_equal(debug[8].children[1].hl.fg, debug[7].hl.bg)
        assert_equal(debug[8].children[1].hl.bg, debug[5].hl.bg)
    end)

    it('notifies subscribers when the configured style changes', function()
        local seen = {}
        local unsubscribe = statuesque.on_style_change(function(style_name)
            seen[#seen + 1] = style_name
        end)

        statuesque.setup({ style = 'capsule', manifold = false })
        statuesque.setup({ style = 'slanted', manifold = false })
        unsubscribe()

        assert_equal(seen[1], 'capsule')
        assert_equal(seen[2], 'slanted')
        assert_equal(statuesque.style_name(), 'slanted')
    end)

    it('keeps interpolated section text readable on low-contrast palettes', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                { text = 'beta' },
                { text = 'gamma' },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                outer = { fg = '#777777', bg = '#777777' },
                inner = { fg = '#222222', bg = '#222222' },
            }),
            'debug'
        )

        assert_equal(debug[1].hl.bg, '#777777')
        assert(contrast(debug[1].hl.fg, debug[1].hl.bg) >= 4.5, debug[1].hl.fg)
        assert_equal(debug[3].hl.bg, '#515151')
        assert(contrast(debug[3].hl.fg, debug[3].hl.bg) >= 4.5, debug[3].hl.fg)
        assert_equal(debug[5].hl.bg, '#2e2e2e')
        assert(contrast(debug[5].hl.fg, debug[5].hl.bg) >= 4.5, debug[5].hl.fg)
    end)

    it('lets interpolation endpoints opt into the pure inner style', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                { text = 'beta' },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                inner_mix = 1,
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[3].hl.bg, '#000000')
    end)

    it('uses mode-reactive statusline outer styles by default', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                { text = 'beta' },
            }, {
                surface = 'statusline',
                sigil = '',
                mode = 'insert',
            }),
            'debug'
        )

        assert_equal(debug[1].hl.bg, '#9ece6a')
        assert_equal(debug[1].hl.fg, '#1a1b26')
    end)

    it('keeps cached Vim fragments reactive to inherited mode backgrounds', function()
        require('statuesque.cache').invalidate('cached-mode-reactive-child')
        vim.api.nvim_set_hl(0, 'StatuesqueCachedModeChild', { fg = '#000001' })

        local cached = {
            cache = { key = 'cached-mode-reactive-child' },
            render = function()
                return {
                    role = 'cached-mode-reactive-child',
                    children = {
                        { text = 'ACP', hl = 'StatuesqueCachedModeChild' },
                    },
                }
            end,
        }
        local bar = statuesque.compose({ cached }, {
            surface = 'statusline',
            sigil = '',
            palette = { '#000001' },
        })
        local prefix = 'StatuesqueModeReactive'

        local normal_rendered = statuesque.render(bar, 'statusline', {
            mode = 'normal',
            inline_highlight_prefix = prefix,
        })
        local normal_child = rendered_highlight_with_fg(normal_rendered, prefix, '#000001')

        local insert_rendered = statuesque.render(bar, 'statusline', {
            mode = 'insert',
            inline_highlight_prefix = prefix,
        })
        local insert_child = rendered_highlight_with_fg(insert_rendered, prefix, '#000001')

        assert(normal_child ~= nil, normal_rendered)
        assert(insert_child ~= nil, insert_rendered)
        assert_equal(normal_child.bg, '#7aa2f7')
        assert_equal(insert_child.bg, '#9ece6a')
    end)

    it('lets statusline opt out and other surfaces opt in to mode-reactive styles', function()
        local static_statusline = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
            }, {
                surface = 'statusline',
                sigil = '',
                mode = 'insert',
                mode_style = false,
            }),
            'debug'
        )
        local static_tabline = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
            }, {
                surface = 'tabline',
                sigil = '',
                mode = 'insert',
            }),
            'debug'
        )
        local mode_tabline = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
            }, {
                surface = 'tabline',
                sigil = '',
                mode = 'insert',
                mode_style = true,
            }),
            'debug'
        )

        assert_equal(static_statusline[1].hl.bg, '#7aa2f7')
        assert_equal(static_tabline[1].hl.bg, '#bb9af7')
        assert_equal(mode_tabline[1].hl.bg, '#9ece6a')
    end)

    it('derives readable mode styles from lualine highlight groups', function()
        vim.api.nvim_set_hl(0, 'lualine_a_insert', { fg = '#777777', bg = '#777777', italic = true })

        local hl = style.mode_style('insert')

        assert_equal(hl.bg, '#777777')
        assert(contrast(hl.fg, hl.bg) >= 4.5, hl.fg)
        assert_equal(hl.bold, true)
        assert_equal(hl.italic, true)

        vim.api.nvim_set_hl(0, 'lualine_a_insert', {})
    end)

    it('uses padded, non-reactive default sigils', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
            }, {
                surface = 'statusline',
                mode_style = false,
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'sigil')
        assert_equal(debug[1].text, '  ')
        assert_equal(debug[1].hl.bg, '#ff9e64')
        assert_equal(debug[3].hl.bg, '#ffffff')
    end)

    it('keeps default sigil colors separate from mode backgrounds', function()
        local mode_backgrounds = {}
        for _, mode in ipairs({ 'normal', 'insert', 'visual', 'replace', 'command', 'terminal' }) do
            mode_backgrounds[style.mode_style(mode).bg] = true
        end

        for _, surface in ipairs({ 'statusline', 'tabline', 'winbar', 'incline' }) do
            local defaults = style.backend_defaults(surface)
            assert(
                not mode_backgrounds[defaults.sigil_hl.bg],
                ('expected %s sigil bg %s to avoid mode colors'):format(surface, defaults.sigil_hl.bg)
            )
        end
    end)

    it('uses tabline slanted separators for winbar surfaces', function()
        local defaults = style.backend_defaults('winbar', { style = 'slanted' })

        assert_equal(defaults.left_separator, '')
        assert_equal(defaults.right_separator, '')
        assert_equal(defaults.inner_left_separator, '')
        assert_equal(defaults.inner_right_separator, '')
    end)

    it('uses placement-specific slanted separators for window labels', function()
        local top = style.backend_defaults('window_label', {
            style = 'slanted',
            placement = { vertical = 'top' },
        })
        local bottom = style.backend_defaults('window_label', {
            style = 'slanted',
            placement = { vertical = 'bottom' },
        })

        assert_equal(top.left_separator, '')
        assert_equal(top.right_separator, '')
        assert_equal(top.inner_left_separator, '')
        assert_equal(top.inner_right_separator, '')
        assert_equal(top.base.bg, nil)

        assert_equal(bottom.left_separator, '')
        assert_equal(bottom.right_separator, '')
        assert_equal(bottom.inner_left_separator, '')
        assert_equal(bottom.inner_right_separator, '')
        assert_equal(bottom.base.bg, nil)
    end)

    it('uses placement-specific capsule colors for window labels', function()
        local top = style.backend_defaults('window_label', {
            style = 'capsule',
            placement = { vertical = 'top' },
        })
        local bottom = style.backend_defaults('window_label', {
            style = 'capsule',
            placement = { vertical = 'bottom' },
        })
        local tabline = style.backend_defaults('tabline', { style = 'capsule' })
        local statusline = style.backend_defaults('statusline', { style = 'capsule' })

        assert_equal(top.left_separator, '')
        assert_equal(top.right_separator, '')
        assert_equal(top.outer.bg, tabline.outer.bg)
        assert_equal(top.inner.bg, tabline.inner.bg)
        assert_equal(top.base.bg, nil)

        assert_equal(bottom.left_separator, '')
        assert_equal(bottom.right_separator, '')
        assert_equal(bottom.outer.bg, statusline.outer.bg)
        assert_equal(bottom.inner.bg, statusline.inner.bg)
        assert_equal(bottom.base.bg, nil)
    end)

    it('renders window-label leading separators against a transparent base by default', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'label' },
            }, {
                surface = 'window_label',
                placement = { vertical = 'bottom' },
                style = 'slanted',
                sigil = '',
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'segment-leading-separator')
        assert_equal(debug[1].children[1].hl.bg, nil)
        assert_equal(debug[1].children[1].hl.fg, debug[2].hl.bg)
    end)

    it('lets window-label config opt into an opaque base background', function()
        local surfaces = require('statuesque.presets.default').surfaces({
            preset = false,
            window_label = {
                background = '#101010',
            },
            surfaces = {
                window_label = {
                    right = {
                        { text = 'label' },
                    },
                    backend = 'incline',
                },
            },
        })
        local debug = statuesque.render(surfaces.window_label, 'debug')

        assert_equal(debug[1].children[1].hl.fg, debug[2].hl.bg)
        assert_equal(debug[1].children[1].hl.bg, '#101010')
    end)

    it('composes right-hand sections with right-oriented separators', function()
        local debug = statuesque.render(
            statuesque.compose({
                left = {
                    { text = 'alpha' },
                },
                right = {
                    { text = 'omega' },
                    { text = 'tail' },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[1].children[1].text, 'alpha')
        assert_separator(debug[2], '')
        assert_equal(debug[3].align, 'right')
        assert_separator(debug[4], '')
        assert_equal(debug[5].children[1].text, 'omega')
        assert_separator(debug[6], '')
        assert_equal(debug[7].children[1].text, 'tail')
        assert_equal(debug[8].role, 'right-edge-padding')
        assert_equal(debug[8].text, ' ')
        assert_equal(debug[8].hl.bg, '#ffffff')
        assert_equal(debug[5].hl.bg, '#0b0b0b')
        assert_equal(debug[6].children[1].hl.bg, '#0b0b0b')
        assert_equal(debug[6].children[2].hl.fg, '#ffffff')
        assert_equal(debug[6].children[2].hl.bg, '#0b0b0b')
        assert_equal(debug[6].children[3].hl.bg, '#ffffff')
        assert_equal(debug[7].hl.bg, '#ffffff')
        assert(statuesque.render(debug, 'statusline'):find('%=', 1, true))
        assert(not statuesque.render(debug, 'text'):find('%=', 1, true))
    end)

    it('uses vertically mirrored block separators for tabline sections', function()
        local debug = statuesque.render(
            statuesque.compose({
                left = {
                    { text = 'alpha' },
                    { text = 'beta' },
                },
                right = {
                    { text = 'omega' },
                    { text = 'tail' },
                },
            }, {
                surface = 'tabline',
                segment_layout = 'adjacent',
                sigil = '',
            }),
            'debug'
        )

        assert_separator(debug[2], '')
        assert_separator(debug[4], '')
        assert_separator(debug[6], '')
        assert_separator(debug[8], '')
        assert_equal(debug[10].role, 'right-edge-padding')
        assert_equal(debug[10].text, ' ')
    end)

    it('suppresses Vim separators for dynamically empty composed sections', function()
        local left = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                function()
                    return false
                end,
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
            }),
            'statusline'
        )

        local right = statuesque.render(
            statuesque.compose({
                right = {
                    function()
                        return false
                    end,
                    { text = 'omega' },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
            }),
            'statusline'
        )

        assert_equal(count_occurrences(left, ''), 1)
        assert_contains(right, '%=')
        assert_equal(count_occurrences(right, ''), 1)
        assert_contains(right, 'omega')
        assert_contains(strip_vim_statusline(right), ' omega')
        assert(not strip_vim_statusline(right):find('omega ', 1, true), right)
        assert_ends_with(strip_vim_statusline(right), ' ')
    end)

    it('keeps right separators around the first visible dynamic section only', function()
        local rendered = statuesque.render(
            statuesque.compose({
                right = {
                    function()
                        return false
                    end,
                    { text = 'utf-8 unix' },
                    { text = 'Top' },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
            }),
            'statusline'
        )

        assert_contains(rendered, '%=')
        assert_contains(rendered, 'utf-8 unix')
        assert_contains(rendered, 'Top')
        assert_equal(count_occurrences(rendered, ''), 2)
        local plain = strip_vim_statusline(rendered)
        assert_contains(plain, ' utf-8 unix')
        assert_contains(plain, 'utf-8 unix  Top')
        assert(not plain:find('Top ', 1, true), rendered)
        assert_ends_with(plain, ' ')
    end)

    it('adds one separator padding cell at the right edge of composed bars', function()
        local left = strip_vim_statusline(statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
            }),
            'statusline'
        ))
        local right = strip_vim_statusline(statuesque.render(
            statuesque.compose({
                right = {
                    { text = 'omega' },
                },
            }, {
                surface = 'statusline',
                sigil = '',
            }),
            'statusline'
        ))

        assert_ends_with(left, ' ')
        assert_ends_with(right, ' ')
        assert(not right:find('omega ', 1, true), right)
    end)

    it('lets incline configure separator sidedness independently', function()
        assert_equal(statuesque.render({ { separator = 'section' } }, 'incline', { side = 'left' })[1], '  ')
        assert_equal(statuesque.render({ { separator = 'section' } }, 'incline', { side = 'right' })[1], '  ')
    end)

    it('renders Vim target syntax with escaping, highlights, and clicks', function()
        local rendered = statuesque.render({
            {
                hl = 'StatuesqueActive',
                on_click = { id = 'domain.select', args = { domain = 1 } },
                '100% Alpha',
            },
        }, 'tabline')

        assert(rendered:find('%#StatuesqueActive#', 1, true), rendered)
        assert(rendered:find('100%% Alpha', 1, true), rendered)
        assert(rendered:find('@v:lua.__statuesque_click@', 1, true), rendered)
        assert(rendered:find('%T', 1, true), rendered)
    end)

    it('keeps cached and uncached installed handlers live across bounded introspection', function()
        local clicks = require('statuesque.clicks')
        local hovers = require('statuesque.hovers')
        local previous_tabline = vim.o.tabline
        local previous_showtabline = vim.o.showtabline

        local function run_case(name, cached)
            local click_calls = 0
            local hover_calls = 0
            local function make_node()
                return {
                    text = 'Action',
                    on_click = function()
                        click_calls = click_calls + 1
                    end,
                    on_hover = function()
                        hover_calls = hover_calls + 1
                    end,
                }
            end
            local render_spec = function()
                return make_node()
            end
            if cached then
                render_spec = {
                    cache = { key = name },
                    render = function()
                        return make_node()
                    end,
                }
            end

            statuesque.set_surface(name, { render_spec })
            hovers.install_surface(name, 'tabline')
            vim.o.showtabline = 2
            vim.o.tabline = statuesque.surface_expression(name, 'tabline')

            local installed = statuesque.render_installed_surface(name, 'tabline')
            local installed_click_id = tonumber(installed:match('%%(%d+)@'))
            local installed_hover_id = hovers._surfaces['tabline:' .. name].spans[1].id
            local handlers_after_install = table_size(clicks._handlers)
            hovers.dispatch_position(name, 'tabline', 1, 1)

            for _ = 1, 12 do
                statuesque.render_surface(name, 'tabline')
                vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true })
            end

            assert(clicks._handlers[installed_click_id] ~= nil)
            assert(hovers._handlers[installed_hover_id] ~= nil)
            assert(hovers._active['tabline:' .. name] ~= nil)
            assert(table_size(clicks._handlers) <= handlers_after_install + 1)
            statuesque.click(installed_click_id, 'l', '')
            hovers.dispatch_position(name, 'tabline', 1, 1)
            assert_equal(click_calls, 1)
            assert_equal(hover_calls, 2)

            hovers.uninstall_surface('tabline')
            clicks.uninstall_target('tabline')
        end

        run_case('regression-uncached-installed-handlers', false)
        run_case('regression-cached-installed-handlers', true)

        vim.o.tabline = previous_tabline
        vim.o.showtabline = previous_showtabline
    end)

    it('regression: bounds direct click handlers and skips unusable hover handlers', function()
        local clicks = require('statuesque.clicks')
        local hovers = require('statuesque.hovers')
        clicks.uninstall_target('tabline')
        hovers.uninstall_surface('tabline')
        local before_clicks = table_size(clicks._handlers)
        local before_hovers = table_size(hovers._handlers)
        local before_hover_id = hovers._next_id

        for _ = 1, 6 do
            statuesque.render({ text = 'Action', on_click = function() end }, 'tabline')
        end

        assert_equal(table_size(clicks._handlers), before_clicks + 1)
        for _ = 1, 6 do
            statuesque.render({ text = 'Hover', on_hover = function() end }, 'tabline')
        end

        assert_equal(table_size(clicks._handlers), before_clicks + 1)
        assert_equal(table_size(hovers._handlers), before_hovers)
        assert_equal(hovers._next_id, before_hover_id)

        statuesque.set_surface('regression-zero-width-hover', {
            { text = '', on_hover = function() end },
        })
        hovers.install_surface('regression-zero-width-hover', 'tabline')
        for _ = 1, 6 do
            assert_equal(statuesque.render_installed_surface('regression-zero-width-hover', 'tabline'), '')
        end

        assert_equal(table_size(hovers._handlers), before_hovers)
        assert_equal(hovers._next_id, before_hover_id)
        hovers.uninstall_surface('tabline')
        clicks.uninstall_target('tabline')
    end)

    it('aborts partial handler generations after repeated render failures', function()
        local clicks = require('statuesque.clicks')
        local hovers = require('statuesque.hovers')
        local before_clicks = table_size(clicks._handlers)
        local before_hovers = table_size(hovers._handlers)

        statuesque.set_surface('failed-handler-generation', {
            {
                text = 'Registered first',
                on_click = function() end,
                on_hover = function() end,
            },
            {
                text = 'Fails second',
                hl = { fg = 'definitely-not-a-color' },
            },
        })
        hovers.install_surface('failed-handler-generation', 'tabline')

        for _ = 1, 8 do
            local ok = pcall(statuesque.render_installed_surface, 'failed-handler-generation', 'tabline')
            assert_equal(ok, false)
        end

        assert_equal(table_size(clicks._handlers), before_clicks)
        assert_equal(table_size(hovers._handlers), before_hovers)
        assert_equal(hovers._surfaces['tabline:failed-handler-generation'], nil)
        hovers.uninstall_surface('tabline')
        clicks.uninstall_target('tabline')
    end)

    it('does not escape already rendered child Vim statusline syntax', function()
        local rendered = statuesque.render({
            {
                hl = { fg = '#ffffff', bg = '#000000' },
                children = {
                    {
                        hl = { fg = '#000000', bg = '#ffffff' },
                        text = 'child',
                    },
                },
            },
        }, 'statusline')

        assert(rendered:find('%#StatuesqueInline1#', 1, true), rendered)
        assert(rendered:find('%#StatuesqueInline2#', 1, true), rendered)
        assert(not rendered:find('%%#StatuesqueInline2#', 1, true), rendered)
    end)

    it('does not append gsub replacement counts while escaping Vim text', function()
        local rendered = statuesque.render({
            {
                hl = { fg = '#ffffff', bg = '#000000' },
                text = 'plain',
            },
        }, 'statusline')

        assert(rendered:find('#plain%*', 1, true), rendered)
        assert(not rendered:find('plain0%*', 1, true), rendered)
    end)

    it('dispatches click callbacks through the public API', function()
        local seen
        local rendered = statuesque.render({
            {
                text = 'Alpha',
                on_click = function(payload)
                    seen = payload
                end,
            },
        }, 'statusline')

        local id = tonumber(rendered:match('%%(%d+)@'))
        assert(id ~= nil, rendered)

        statuesque.click(id, 'l', 's', { surface = 'tabline' })

        assert(seen ~= nil)
        assert_equal(seen.button, 'l')
        assert_equal(seen.modifiers, 's')
        assert_equal(seen.surface, 'tabline')
        assert_equal(seen.target, 'statusline')
    end)

    it('dispatches hover callbacks through the hover registry', function()
        local hovers = require('statuesque.hovers')
        local seen
        local id = hovers.register(function(payload)
            seen = payload
            return 'hovered'
        end, {
            node = { id = 'node:hover' },
            target = 'tabline',
        })

        assert_equal(hovers.dispatch(id, 'enter', { row = 1, col = 2 }), 'hovered')
        assert_equal(seen.id, id)
        assert_equal(seen.phase, 'enter')
        assert_equal(seen.row, 1)
        assert_equal(seen.col, 2)
        assert_equal(seen.node.id, 'node:hover')
        assert_equal(seen.target, 'tabline')

        local action_id = hovers.register({ id = 'hover.action', args = { tab = 3 } })
        local payload = hovers.dispatch(action_id, 'leave')
        assert_equal(payload.action, 'hover.action')
        assert_equal(payload.args.tab, 3)
        assert_equal(payload.phase, 'leave')
    end)

    it('dispatches installed-surface hover spans from rendered columns', function()
        local hovers = require('statuesque.hovers')
        local seen = {}
        hovers._active = {}

        statuesque.set_surface('hover-tabline', {
            ' ',
            {
                text = 'Alpha',
                on_hover = function(payload)
                    seen[#seen + 1] = payload
                end,
            },
            ' ',
            {
                text = 'Beta',
                on_hover = function(payload)
                    seen[#seen + 1] = payload
                end,
            },
        })

        assert_equal(statuesque.render_installed_surface('hover-tabline', 'tabline'), ' Alpha Beta')

        hovers.dispatch_position('hover-tabline', 'tabline', 2, 1)
        hovers.dispatch_position('hover-tabline', 'tabline', 3, 1)
        hovers.dispatch_position('hover-tabline', 'tabline', 8, 1)
        hovers.dispatch_position('hover-tabline', 'tabline', 99, 1)

        assert_equal(seen[1].phase, 'enter')
        assert_equal(seen[1].col, 2)
        assert_equal(seen[1].surface, 'hover-tabline')
        assert_equal(seen[2].phase, 'move')
        assert_equal(seen[3].phase, 'leave')
        assert_equal(seen[4].phase, 'enter')
        assert_equal(seen[4].node.text, 'Beta')
        assert_equal(seen[5].phase, 'leave')
    end)

    it('dispatches hover leave when the mouse moves off an installed surface', function()
        local hovers = require('statuesque.hovers')
        local previous_targets = hovers._installed_targets
        local seen = {}
        hovers._active = {}
        hovers._installed_targets = {
            tabline = 'leave-tabline',
        }

        statuesque.set_surface('leave-tabline', {
            {
                text = 'Alpha',
                on_hover = function(payload)
                    seen[#seen + 1] = payload
                end,
            },
        })

        assert_equal(statuesque.render_installed_surface('leave-tabline', 'tabline'), 'Alpha')
        hovers.handle_mousemove({
            screenrow = 1,
            screencol = 1,
        })
        hovers.handle_mousemove({
            screenrow = 2,
            screencol = 1,
        })

        assert_equal(seen[1].phase, 'enter')
        assert_equal(seen[1].surface, 'leave-tabline')
        assert_equal(seen[2].phase, 'leave')
        assert_equal(seen[2].surface, 'leave-tabline')
        assert_equal(seen[2].mouse.screenrow, 2)

        hovers._installed_targets = previous_targets
        hovers._active = {}
    end)

    it('replays hover spans when Vim render fragments come from cache', function()
        local hovers = require('statuesque.hovers')
        local calls = 0
        local seen = {}
        hovers._active = {}

        statuesque.set_surface('cached-hover-tabline', {
            {
                id = 'cached-hover-fragment',
                cache = { key = 'cached-hover-fragment' },
                render = function()
                    calls = calls + 1
                    return {
                        'prefix:',
                        {
                            text = 'Hot',
                            on_hover = function(payload)
                                seen[#seen + 1] = payload
                            end,
                        },
                    }
                end,
            },
        })

        assert_equal(statuesque.render_installed_surface('cached-hover-tabline', 'tabline'), 'prefix:Hot')
        assert_equal(statuesque.render_installed_surface('cached-hover-tabline', 'tabline'), 'prefix:Hot')
        assert_equal(calls, 1)

        hovers.dispatch_position('cached-hover-tabline', 'tabline', 8, 1)

        assert_equal(seen[1].phase, 'enter')
        assert_equal(seen[1].node.text, 'Hot')
    end)

    it('replaces installed-surface click and hover handler generations', function()
        local clicks = require('statuesque.clicks')
        local hovers = require('statuesque.hovers')
        local before_clicks = table_size(clicks._handlers)
        local before_hovers = table_size(hovers._handlers)

        statuesque.set_surface('bounded-tabline-handlers', function()
            return {
                {
                    text = 'Action',
                    on_click = function() end,
                    on_hover = function() end,
                },
            }
        end)
        hovers.install_surface('bounded-tabline-handlers', 'tabline')

        statuesque.render_installed_surface('bounded-tabline-handlers', 'tabline')
        local first_clicks = table_size(clicks._handlers)
        local first_hovers = table_size(hovers._handlers)
        statuesque.render_installed_surface('bounded-tabline-handlers', 'tabline')

        assert_equal(first_clicks, before_clicks + 1)
        assert_equal(first_hovers, before_hovers + 1)
        assert_equal(table_size(clicks._handlers), first_clicks)
        assert_equal(table_size(hovers._handlers), first_hovers)

        hovers.uninstall_surface('tabline')
        clicks.uninstall_target('tabline')
    end)

    it('emits hover leave when active generations retire or uninstall', function()
        local hovers = require('statuesque.hovers')
        local phases = {}
        local hover_node = {
            text = 'Hover',
            on_hover = function(payload)
                phases[#phases + 1] = payload.phase
            end,
        }

        statuesque.set_surface('active-hover-teardown', { hover_node })
        hovers.install_surface('active-hover-teardown', 'tabline')
        statuesque.render_installed_surface('active-hover-teardown', 'tabline')
        hovers.dispatch_position('active-hover-teardown', 'tabline', 1, 1)

        statuesque.set_surface('active-hover-teardown', { text = 'Plain' })
        statuesque.render_installed_surface('active-hover-teardown', 'tabline')
        assert_equal(table.concat(phases, ','), 'enter,leave')
        assert_equal(next(hovers._active), nil)
        assert_equal(hovers._mousemove_installed, false)

        statuesque.set_surface('active-hover-teardown', { hover_node })
        statuesque.render_installed_surface('active-hover-teardown', 'tabline')
        hovers.dispatch_position('active-hover-teardown', 'tabline', 1, 1)
        hovers.uninstall_surface('tabline')
        assert_equal(table.concat(phases, ','), 'enter,leave,enter,leave')
        assert_equal(next(hovers._active), nil)
    end)

    it('keeps installed winbar hover state separate per window', function()
        local hovers = require('statuesque.hovers')
        local seen = {}
        statuesque.set_surface('window-hover', function(context)
            return {
                {
                    text = tostring(context.winid),
                    on_hover = function(payload)
                        seen[#seen + 1] = {
                            phase = payload.phase,
                            text = payload.node.text,
                        }
                    end,
                },
            }
        end)
        hovers.install_surface('window-hover', 'winbar')

        statuesque.render_surface('window-hover', 'winbar', {
            winid = 101,
            bufnr = 201,
            _statuesque_installed_render = true,
        })
        statuesque.render_surface('window-hover', 'winbar', {
            winid = 102,
            bufnr = 202,
            _statuesque_installed_render = true,
        })
        hovers.dispatch_position('window-hover', 'winbar', 1, 1, { winid = 101 })
        hovers.dispatch_position('window-hover', 'winbar', 1, 1, { winid = 102 })

        assert_equal(seen[1].phase, 'enter')
        assert_equal(seen[1].text, '101')
        assert_equal(seen[2].phase, 'leave')
        assert_equal(seen[2].text, '101')
        assert_equal(seen[3].phase, 'enter')
        assert_equal(seen[3].text, '102')
        hovers.uninstall_surface('winbar')
    end)

    it('regression: retires click and hover generations when a winbar window closes', function()
        local clicks = require('statuesque.clicks')
        local hovers = require('statuesque.hovers')
        hovers.uninstall_surface('winbar')
        clicks.uninstall_target('winbar')
        local before_clicks = table_size(clicks._handlers)
        local before_hovers = table_size(hovers._handlers)

        vim.cmd('split')
        local winid = vim.api.nvim_get_current_win()
        local bufnr = vim.api.nvim_get_current_buf()
        local phases = {}
        statuesque.set_surface('regression-closed-winbar', {
            {
                text = 'Window',
                on_click = function() end,
                on_hover = function(payload)
                    phases[#phases + 1] = payload.phase
                end,
            },
        })
        hovers.install_surface('regression-closed-winbar', 'winbar')
        statuesque.render_surface('regression-closed-winbar', 'winbar', {
            winid = winid,
            bufnr = bufnr,
            _statuesque_installed_render = true,
        })

        assert_equal(table_size(clicks._handlers), before_clicks + 1)
        assert_equal(table_size(hovers._handlers), before_hovers + 1)
        hovers.dispatch_position('regression-closed-winbar', 'winbar', 1, 1, { winid = winid })
        vim.api.nvim_win_close(winid, true)

        assert_equal(table_size(clicks._handlers), before_clicks)
        assert_equal(table_size(hovers._handlers), before_hovers)
        for _, record in pairs(clicks._surfaces) do
            assert(record.winid ~= winid)
        end
        for _, record in pairs(hovers._surfaces) do
            assert(record.winid ~= winid)
        end
        assert_equal(table.concat(phases, ','), 'enter,leave')

        hovers.uninstall_surface('winbar')
        clicks.uninstall_target('winbar')
    end)

    it('restores mousemove state when installed surfaces stop rendering hovers', function()
        local hovers = require('statuesque.hovers')
        local previous_mousemoveevent = vim.o.mousemoveevent
        vim.o.mousemoveevent = false
        vim.keymap.set('n', '<MouseMove>', '<Ignore>', { desc = 'Previous mousemove mapping' })

        statuesque.set_surface('temporary-hover', {
            { text = 'Hover', on_hover = function() end },
        })
        hovers.install_surface('temporary-hover', 'tabline')
        statuesque.render_installed_surface('temporary-hover', 'tabline')
        assert_equal(vim.o.mousemoveevent, true)

        statuesque.set_surface('temporary-hover', { text = 'Plain' })
        statuesque.render_installed_surface('temporary-hover', 'tabline')
        local mapping = vim.fn.maparg('<MouseMove>', 'n', false, true)
        assert_equal(vim.o.mousemoveevent, false)
        assert_equal(mapping.desc, 'Previous mousemove mapping')

        vim.keymap.del('n', '<MouseMove>')
        vim.o.mousemoveevent = previous_mousemoveevent
        hovers.uninstall_surface('tabline')
    end)

    it('regression: restores exact mouse mappings without overwriting later user state', function()
        local hovers = require('statuesque.hovers')
        hovers.uninstall_surface('statusline')
        hovers.uninstall_surface('tabline')
        hovers.uninstall_surface('winbar')
        pcall(vim.keymap.del, 'n', '<MouseMove>')
        local previous_mousemoveevent = vim.o.mousemoveevent
        vim.o.mousemoveevent = false

        statuesque.set_surface('regression-mousemove', {
            { text = 'Hover', on_hover = function() end },
        })
        hovers.install_surface('regression-mousemove', 'tabline')

        vim.api.nvim_exec2(
            [[
function! s:StatuesqueMouseMoveProbe()
    return ''
endfunction
nnoremap <script> <MouseMove> :call <SID>StatuesqueMouseMoveProbe()<CR>
]],
            { output = false }
        )
        local original_script_mapping = vim.fn.maparg('<MouseMove>', 'n', false, true)
        statuesque.render_installed_surface('regression-mousemove', 'tabline')
        statuesque.set_surface('regression-mousemove', { text = 'Plain' })
        statuesque.render_installed_surface('regression-mousemove', 'tabline')
        local restored_script_mapping = vim.fn.maparg('<MouseMove>', 'n', false, true)
        assert(
            vim.deep_equal(restored_script_mapping, original_script_mapping),
            ('expected exact mapping restoration:\nbefore=%s\nafter=%s'):format(
                vim.inspect(original_script_mapping),
                vim.inspect(restored_script_mapping)
            )
        )

        vim.cmd('nunmap <MouseMove>')
        vim.cmd('nnoremap <MouseMove> <Nop>')
        statuesque.set_surface('regression-mousemove', {
            { text = 'Hover', on_hover = function() end },
        })
        statuesque.render_installed_surface('regression-mousemove', 'tabline')
        statuesque.set_surface('regression-mousemove', { text = 'Plain' })
        statuesque.render_installed_surface('regression-mousemove', 'tabline')
        local nop_mapping = vim.fn.maparg('<MouseMove>', 'n', false, true)
        assert_equal(nop_mapping.lhs, '<MouseMove>')
        assert_equal(nop_mapping.noremap, 1)

        vim.cmd('nunmap <MouseMove>')
        vim.keymap.set('n', '<MouseMove>', '<Ignore>', { desc = 'Before Statuesque' })
        statuesque.set_surface('regression-mousemove', {
            { text = 'Hover', on_hover = function() end },
        })
        statuesque.render_installed_surface('regression-mousemove', 'tabline')
        vim.keymap.set('n', '<MouseMove>', '<Nop>', { desc = 'After Statuesque' })
        vim.o.mousemoveevent = false
        statuesque.set_surface('regression-mousemove', { text = 'Plain' })
        statuesque.render_installed_surface('regression-mousemove', 'tabline')
        local user_mapping = vim.fn.maparg('<MouseMove>', 'n', false, true)
        assert_equal(user_mapping.desc, 'After Statuesque')
        assert_equal(vim.o.mousemoveevent, false)

        vim.keymap.del('n', '<MouseMove>')
        vim.o.mousemoveevent = false
        statuesque.set_surface('regression-mousemove', {
            { text = 'Hover', on_hover = function() end },
        })
        statuesque.render_installed_surface('regression-mousemove', 'tabline')
        vim.o.mousemoveevent = true
        statuesque.set_surface('regression-mousemove', { text = 'Plain' })
        statuesque.render_installed_surface('regression-mousemove', 'tabline')
        assert_equal(vim.o.mousemoveevent, true)

        pcall(vim.keymap.del, 'n', '<MouseMove>')
        vim.o.mousemoveevent = previous_mousemoveevent
        hovers.uninstall_surface('tabline')
    end)

    it('renders configured surfaces from providers', function()
        statuesque.register_provider('demo', function(context)
            return {
                'domain:',
                context.domain,
            }
        end)
        statuesque.set_surface('tabline', 'demo')

        assert_equal(statuesque.render_surface('tabline', 'text', { domain = 'Alpha' }), 'domain:Alpha')
    end)

    it('renders an Incline-compatible limited table with explicit degradation metadata', function()
        local rendered = statuesque.render({
            {
                id = 'tab:1',
                role = 'tab',
                hl = 'StatuesqueTab',
                on_click = { id = 'tab.select', args = { tab = 1 } },
                on_hover = { id = 'tab.preview', args = { tab = 1 } },
                'Alpha',
            },
        }, 'incline')

        assert_equal(incline_chunk_text(rendered[1]), 'Alpha')
        assert_equal(rendered[1].group, 'StatuesqueTab')
        assert_equal(rendered[1].statuesque.id, 'tab:1')
        assert_equal(rendered[1].statuesque.role, 'tab')
        assert_equal(rendered[1].statuesque.on_click, 'unsupported')
        assert_equal(rendered[1].statuesque.on_hover, 'unsupported')
    end)

    it('does not emit structured metadata on groupless Incline nodes', function()
        local rendered = statuesque.render({
            {
                role = 'window-label',
                'Alpha',
            },
        }, 'incline')

        assert_equal(incline_chunk_text(rendered[1]), 'Alpha')
        assert_equal(rendered[1].statuesque, nil)
    end)

    it('registers inline highlight groups for generated Incline table highlights', function()
        local rendered = statuesque.render({
            {
                hl = { fg = '#112233', bg = '#445566', bold = true },
                'Alpha',
            },
        }, 'incline')

        assert_equal(incline_chunk_text(rendered[1]), 'Alpha')
        assert_equal(rendered[1].group, 'StatuesqueIncline1')

        local namespace = require('statuesque.render.incline').highlight_namespace()
        local global = vim.api.nvim_get_hl(0, { name = 'StatuesqueIncline1', link = false })
        local hl = vim.api.nvim_get_hl(namespace, { name = 'StatuesqueIncline1', link = false })
        assert_equal(next(global), nil)
        assert_equal(hl.fg, 0x112233)
        assert_equal(hl.bg, 0x445566)
        assert_equal(hl.bold, true)
    end)

    it('replays cached Incline inline highlight definitions', function()
        local cached = {
            id = 'cached-incline-highlight',
            cache = { key = 'cached-incline-highlight' },
            render = function()
                return {
                    hl = { fg = '#223344', bg = '#556677' },
                    text = 'Cached',
                }
            end,
        }

        local first = statuesque.render({ cached }, 'incline')
        assert_equal(first[1].group, 'StatuesqueIncline1')
        local namespace = require('statuesque.render.incline').highlight_namespace()
        vim.api.nvim_set_hl(namespace, 'StatuesqueIncline1', { fg = '#ffffff', bg = '#000000' })

        local second = statuesque.render({ cached }, 'incline')
        assert_equal(second[1].group, 'StatuesqueIncline1')

        local hl = vim.api.nvim_get_hl(namespace, { name = 'StatuesqueIncline1', link = false })
        assert_equal(hl.fg, 0x223344)
        assert_equal(hl.bg, 0x556677)
    end)

    it('scopes generated Incline highlight groups per window', function()
        local first = statuesque.render({
            {
                hl = { fg = '#101010', bg = '#202020' },
                'Left',
            },
        }, 'incline', { winid = 11 })
        local second = statuesque.render({
            {
                hl = { fg = '#303030', bg = '#404040' },
                'Right',
            },
        }, 'incline', { winid = 22 })

        assert_equal(first[1].group, 'StatuesqueInclineW11_1')
        assert_equal(second[1].group, 'StatuesqueInclineW22_1')

        local namespace = require('statuesque.render.incline').highlight_namespace()
        local first_hl = vim.api.nvim_get_hl(namespace, { name = 'StatuesqueInclineW11_1', link = false })
        local second_hl = vim.api.nvim_get_hl(namespace, { name = 'StatuesqueInclineW22_1', link = false })
        assert_equal(first_hl.fg, 0x101010)
        assert_equal(first_hl.bg, 0x202020)
        assert_equal(second_hl.fg, 0x303030)
        assert_equal(second_hl.bg, 0x404040)
    end)

    it('renders window-label widgets from the context buffer', function()
        local previous_devicons = package.loaded['nvim-web-devicons']
        package.loaded['nvim-web-devicons'] = {
            get_icon_color_by_filetype = function(filetype)
                assert_equal(filetype, 'lua')
                return '', '#51a0cf'
            end,
        }

        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(bufnr, ('/tmp/statuesque-window-label-%d.lua'):format(bufnr))
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'local label = true' })
        vim.bo[bufnr].filetype = 'lua'
        vim.b[bufnr].vgit_status = {
            added = 2,
            changed = 3,
            removed = 1,
        }

        local rendered = statuesque.render({
            { name = 'git_diff' },
            { name = 'filename', opts = { filetype_icon = true } },
        }, 'text', { bufnr = bufnr })

        package.loaded['nvim-web-devicons'] = previous_devicons
        vim.api.nvim_buf_delete(bufnr, { force = true })

        assert_contains(rendered, ' 2')
        assert_contains(rendered, ' 3')
        assert_contains(rendered, ' 1')
        assert_contains(rendered, (' statuesque-window-label-%d.lua +'):format(bufnr))
        assert_contains(rendered, ('statuesque-window-label-%d.lua +'):format(bufnr))
    end)

    it('prefers Stratum path diff summaries for Git diff widgets', function()
        local previous_stratum = package.loaded['stratum']
        package.loaded['stratum'] = {
            path_summary = function(path)
                assert(path:find('statuesque-stratum-diff', 1, true), path)
                return {
                    added = 4,
                    changed = 2,
                    removed = 1,
                }
            end,
        }
        package.loaded['statuesque.widgets.git_diff'] = nil

        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(bufnr, ('/tmp/statuesque-stratum-diff-%d.lua'):format(bufnr))
        vim.b[bufnr].vgit_status = {
            added = 9,
            changed = 9,
            removed = 9,
        }

        local rendered = statuesque.render({
            { name = 'git_diff' },
        }, 'text', { bufnr = bufnr })

        package.loaded['stratum'] = previous_stratum
        package.loaded['statuesque.widgets.git_diff'] = nil
        vim.api.nvim_buf_delete(bufnr, { force = true })

        assert_contains(rendered, ' 4')
        assert_contains(rendered, ' 2')
        assert_contains(rendered, ' 1')
        assert(not rendered:find('9', 1, true), rendered)
    end)

    it('subscribes Stratum Git diff widgets to repository updates', function()
        local previous_stratum = package.loaded['stratum']
        local summary = {
            added = 1,
            changed = 0,
            removed = 0,
        }
        package.loaded['stratum'] = {
            path_summary = function(path)
                assert(path:find('statuesque-stratum-refresh', 1, true), path)
                return summary
            end,
        }
        package.loaded['statuesque.widgets.git_diff'] = nil

        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(bufnr, ('/tmp/statuesque-stratum-refresh-%d.lua'):format(bufnr))
        local widget = require('statuesque.widgets.git_diff')()
        local updates = 0

        assert_contains(
            statuesque.render({ widget }, 'text', {
                bufnr = bufnr,
                on_update = function(component)
                    assert_equal(component, widget)
                    updates = updates + 1
                end,
            }),
            ' 1'
        )
        summary = {
            added = 0,
            changed = 2,
            removed = 1,
        }

        vim.api.nvim_exec_autocmds('User', { pattern = 'StratumRepositoryUpdated' })
        local rendered = statuesque.render({ widget }, 'text', { bufnr = bufnr })

        package.loaded['stratum'] = previous_stratum
        package.loaded['statuesque.widgets.git_diff'] = nil
        vim.api.nvim_buf_delete(bufnr, { force = true })

        assert_equal(updates, 1)
        assert_contains(rendered, ' 2')
        assert_contains(rendered, ' 1')
    end)

    it('falls back to buffer Git diff state while Stratum is not ready', function()
        local previous_stratum = package.loaded['stratum']
        package.loaded['stratum'] = {
            path_summary = function()
                return nil, 'repository state is not ready: starting'
            end,
        }
        package.loaded['statuesque.widgets.git_diff'] = nil

        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(bufnr, ('/tmp/statuesque-stratum-not-ready-%d.lua'):format(bufnr))
        vim.b[bufnr].vgit_status = {
            added = 1,
            changed = 2,
            removed = 3,
        }

        local rendered = statuesque.render({
            { name = 'git_diff' },
        }, 'text', { bufnr = bufnr })

        package.loaded['stratum'] = previous_stratum
        package.loaded['statuesque.widgets.git_diff'] = nil
        vim.api.nvim_buf_delete(bufnr, { force = true })

        assert_contains(rendered, ' 1')
        assert_contains(rendered, ' 2')
        assert_contains(rendered, ' 3')
    end)

    it('normalizes Git diff counts from common plugin buffer variables', function()
        local previous_stratum = package.loaded['stratum']
        package.loaded['stratum'] = {
            path_summary = function()
                return nil
            end,
        }
        package.loaded['statuesque.widgets.git_diff'] = nil

        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(bufnr, ('/tmp/statuesque-git-diff-generic-%d.lua'):format(bufnr))
        vim.b[bufnr].minidiff_summary = {
            add = 5,
            change = 4,
            delete = 3,
        }

        local rendered = statuesque.render({
            { name = 'git_diff' },
        }, 'text', { bufnr = bufnr })

        package.loaded['stratum'] = previous_stratum
        package.loaded['statuesque.widgets.git_diff'] = nil
        vim.api.nvim_buf_delete(bufnr, { force = true })

        assert_contains(rendered, ' 5')
        assert_contains(rendered, ' 4')
        assert_contains(rendered, ' 3')
    end)

    it('can render filename buffer-state flags as separate nodes', function()
        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(bufnr, ('/tmp/statuesque-filename-flags-%d.lua'):format(bufnr))
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'local flags = true' })
        vim.bo[bufnr].modified = true
        vim.bo[bufnr].readonly = true

        local debug = statuesque.render({
            {
                name = 'filename',
                opts = {
                    max_width = 48,
                    separate_flags = true,
                    modified_text = '[+]',
                    readonly_text = '[-]',
                    modified_hl = 'StatuesqueModifiedFilename',
                },
            },
        }, 'debug', { bufnr = bufnr })

        vim.api.nvim_buf_delete(bufnr, { force = true })

        assert_equal(debug[1].role, 'filename')
        assert_equal(debug[1].hl, 'StatuesqueModifiedFilename')
        assert_contains(debug[1].text, ('statuesque-filename-flags-%d.lua'):format(bufnr))
        assert_equal(debug[2].role, 'filename-modified')
        assert_equal(debug[2].text, '[+]')
        assert_equal(debug[3].role, 'filename-readonly')
        assert_equal(debug[3].text, '[-]')
    end)

    it('renders quickfix state for status surfaces', function()
        vim.fn.setqflist({}, 'r', {
            title = 'Build',
            items = {
                {
                    filename = '/tmp/statuesque-quickfix.lua',
                    lnum = 3,
                    col = 1,
                    text = 'quickfix item',
                },
            },
        })

        local rendered = statuesque.render({
            name = 'quickfix',
            opts = {
                title = true,
            },
        }, 'statusline')

        vim.fn.setqflist({}, 'r')

        assert_contains(rendered, 'QF 1/1 Build')
    end)

    it('renders DAP status when nvim-dap has an active session', function()
        local previous_dap = package.loaded.dap
        package.loaded.dap = {
            session = function()
                return {
                    config = {
                        name = 'Debug Demo',
                    },
                }
            end,
            status = function()
                return 'breakpoint'
            end,
        }

        local rendered = statuesque.render({
            name = 'dap',
        }, 'statusline')

        package.loaded.dap = previous_dap

        assert_contains(rendered, ' breakpoint Debug Demo')
    end)

    it('matches explicit foregrounds against the configured palette and background', function()
        local matched = style.match_palette_color('#f1c16d', '#101010', {
            palette = {
                '#274060',
                '#f8c97a',
            },
        })

        assert_equal(matched, '#f8c97a')
        assert(contrast(matched, '#101010') >= 4.5)
    end)

    it('keeps semantic foregrounds instead of replacing them with distant readable palette colors', function()
        local matched = style.match_palette_color('#61AFEF', '#9d4d5c', {
            min_contrast = 3.5,
            palette = {
                '#ffffff',
            },
        })
        local red, _, blue = rgb(matched)

        assert(matched ~= '#ffffff', matched)
        assert(blue > red, matched)
        assert(contrast(matched, '#9d4d5c') >= 3.5, matched)
    end)

    it('still accepts nearby palette colors that preserve the source color identity', function()
        local matched = style.match_palette_color('#61AFEF', '#1f2335', {
            palette = {
                '#7dcfff',
                '#ffffff',
            },
        })

        assert_equal(matched, '#7dcfff')
    end)

    it('uses semantic contrast for explicit child foreground accents on mode backgrounds', function()
        vim.api.nvim_set_hl(0, 'StatuesqueSemanticBlue', {
            fg = '#61AFEF',
        })

        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'ACP', hl = 'StatuesqueSemanticBlue' },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                palette = {
                    '#ffffff',
                },
                outer = { fg = '#ffffff', bg = '#9d4d5c' },
                inner = { fg = '#ffffff', bg = '#9d4d5c' },
            }),
            'debug'
        )

        local matched = debug[1].children[1].hl.fg
        local red, _, blue = rgb(matched)

        assert(matched ~= '#ffffff', matched)
        assert(blue > red, matched)
        assert(contrast(matched, '#9d4d5c') >= 3.5, matched)
    end)

    it('darkens semantic-rich sections before muting recognizable accents', function()
        vim.api.nvim_set_hl(0, 'StatuesqueSemanticReplaceBlue', {
            fg = '#61AFEF',
        })
        vim.api.nvim_set_hl(0, 'StatuesqueSemanticReplaceYellow', {
            fg = '#E5C07B',
        })

        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'ACP', hl = 'StatuesqueSemanticReplaceBlue' },
                    { text = 'idle', hl = 'StatuesqueSemanticReplaceYellow' },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                palette = {
                    '#ffffff',
                },
                outer = { fg = '#ffffff', bg = '#f7768e' },
                inner = { fg = '#ffffff', bg = '#f7768e' },
            }),
            'debug'
        )

        local matched = debug[1].children[1].hl.fg
        local red, green, blue = rgb(matched)
        local matched_bg = debug[1].children[1].hl.bg

        assert(matched ~= '#ffffff', matched)
        assert(blue >= red and blue >= green, matched)
        assert(luminance(matched_bg) < luminance('#f7768e'), matched_bg)
        assert(contrast(matched, matched_bg) >= 3.5, matched)

        local warm = debug[1].children[2].hl.fg
        local warm_red, warm_green, warm_blue = rgb(warm)
        assert(warm ~= '#ffffff', warm)
        assert(warm_red >= warm_blue and warm_green >= warm_blue, warm)
        assert(contrast(warm, debug[1].children[2].hl.bg) >= 3.5, warm)
    end)

    it('keeps multi-accent widget backgrounds coherent before repairing foregrounds', function()
        local background = '#f7768e'
        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'ACP', hl = { fg = '#61AFEF' } },
                    { text = 'idle', hl = { fg = '#98C379' } },
                    { text = 'err', hl = { fg = '#E06C75' } },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                palette = {
                    '#ffffff',
                    '#3b4261',
                    '#89ddff',
                    '#9ece6a',
                    '#ff007c',
                },
                outer = { fg = '#ffffff', bg = background },
                inner = { fg = '#ffffff', bg = background },
            }),
            'debug'
        )

        assert(luminance(debug[1].hl.bg) < luminance(background), debug[1].hl.bg)
        for _, child in ipairs(debug[1].children) do
            local matched = child.hl.fg
            assert_equal(child.hl.bg, debug[1].hl.bg)
            assert(contrast(matched, child.hl.bg) >= 3.5, matched)
        end
    end)

    it('keeps Legate-like semantic accents muted but recognizable on mode backgrounds', function()
        local background = '#6a85ca'
        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'pending', hl = { fg = '#61AFEF' } },
                    { text = ' neutral', hl = { fg = '#7F848E' } },
                    { text = ' success', hl = { fg = '#98C379' } },
                    { text = ' failure', hl = { fg = '#E06C75' } },
                    { text = ' waiting', hl = { fg = '#E5C07B' } },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                palette = {
                    '#ffffff',
                    '#3b4261',
                    '#89ddff',
                    '#9ece6a',
                    '#ff007c',
                },
                outer = { fg = '#ffffff', bg = background },
                inner = { fg = '#ffffff', bg = background },
            }),
            'debug'
        )

        local pending = debug[1].children[1].hl.fg
        local neutral = debug[1].children[2].hl.fg
        local success = debug[1].children[3].hl.fg
        local failure = debug[1].children[4].hl.fg
        local waiting = debug[1].children[5].hl.fg
        local pending_red, pending_green, pending_blue = rgb(pending)
        local success_red, success_green, success_blue = rgb(success)
        local failure_red, failure_green, failure_blue = rgb(failure)
        local waiting_red, waiting_green, waiting_blue = rgb(waiting)

        assert(luminance(debug[1].hl.bg) < luminance(background), debug[1].hl.bg)
        assert_equal(pending, '#61AFEF')
        assert_equal(neutral, '#7F848E')
        assert_equal(success, '#98C379')
        assert_equal(failure, '#E06C75')
        assert_equal(waiting, '#E5C07B')
        for _, color in ipairs({ pending, neutral, success, failure, waiting }) do
            assert(color ~= '#000000' and color ~= '#ffffff', color)
            assert(contrast(color, debug[1].hl.bg) >= 3.5, color)
        end
        assert(pending_blue > pending_red and pending_blue > pending_green, pending)
        assert(channel_spread(neutral) <= 40, neutral)
        assert(success_green > success_red and success_green > success_blue, success)
        assert(failure_red > failure_green and failure_red > failure_blue, failure)
        assert(waiting_red > waiting_blue and waiting_green > waiting_blue, waiting)
    end)

    it('brackets darkened semantic sections with the original section color', function()
        local background = '#f7768e'
        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'ACP', hl = { fg = '#61AFEF' } },
                    { text = ' idle', hl = { fg = '#98C379' } },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'gapped',
                sigil = '',
                mode_style = false,
                palette = false,
                outer = { fg = '#ffffff', bg = background },
                inner = { fg = '#ffffff', bg = background },
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'segment-leading-separator-chrome-inner')
        assert_equal(debug[1].children[1].hl.bg, background)
        assert_equal(debug[2].role, 'section')
        assert(debug[2].hl.bg ~= background, debug[2].hl.bg)
        assert_equal(debug[2].style.semantic_chrome.bg, background)
        assert_equal(debug[3].role, 'segment-trailing-separator-chrome-outer')
        assert_equal(debug[3].children[1].role, 'segment-trailing-separator-chrome-outer-padding-before')
        assert_equal(debug[3].children[1].text, ' ')
        assert_equal(debug[3].children[1].hl.bg, debug[2].hl.bg)
        assert_equal(debug[3].children[2].role, 'segment-trailing-separator-chrome-outer-glyph')
        assert_equal(debug[3].children[2].hl.bg, background)
        assert_equal(debug[4], nil)
    end)

    it('keeps right-edge partial chrome flush with the surface edge', function()
        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'lua', hl = { fg = '#7aa2f7' }, exact_highlight = true },
                },
            }, {
                surface = 'window_label',
                style = 'capsule',
                placement = { vertical = 'bottom' },
                side = 'right',
                sigil = '',
                palette = false,
                outer = { fg = '#ffffff', bg = '#7aa2f7' },
                inner = { fg = '#ffffff', bg = '#7aa2f7' },
            }),
            'debug'
        )

        assert_equal(debug[#debug].role, 'segment-trailing-separator-chrome-outer')
        assert_equal(debug[#debug].children[1].role, 'segment-trailing-separator-chrome-outer-padding-before')
        assert_equal(debug[#debug].children[1].text, ' ')
        assert_equal(debug[#debug].children[2].role, 'segment-trailing-separator-chrome-outer-glyph')
    end)

    it('chromes adjacent exits from darkened semantic sections', function()
        local background = '#f7768e'
        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'ACP', hl = { fg = '#61AFEF' } },
                    { text = ' idle', hl = { fg = '#98C379' } },
                },
                { text = ' ok' },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                palette = false,
                outer = { fg = '#ffffff', bg = background },
                inner = { fg = '#ffffff', bg = '#303030' },
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'section')
        assert_equal(debug[1].style.semantic_chrome.bg, background)
        assert_equal(debug[2].role, 'separator-chrome-outer')
        assert_equal(debug[2].children[1].hl.bg, background)
        assert_equal(debug[3].role, 'separator-chrome-inner')
        assert_equal(debug[3].children[1].hl.fg, background)
        assert_equal(debug[4].role, 'section')
        assert(debug[4].style.semantic_chrome == nil, vim.inspect(debug[4].style.semantic_chrome))
    end)

    it('repairs foregrounds instead of brightening already-dark sections', function()
        local background = '#101010'
        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'dim', hl = { fg = '#202020' } },
                    { text = ' muted', hl = { fg = '#252525' } },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'gapped',
                sigil = '',
                mode_style = false,
                palette = false,
                outer = { fg = '#ffffff', bg = background },
                inner = { fg = '#ffffff', bg = background },
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'segment-leading-separator')
        assert_equal(debug[2].role, 'section')
        assert_equal(debug[2].hl.bg, background)
        assert(debug[2].style.semantic_chrome == nil, vim.inspect(debug[2].style.semantic_chrome))
        for _, child in ipairs(debug[2].children) do
            assert(luminance(child.hl.fg) > luminance('#252525'), child.hl.fg)
            assert(contrast(child.hl.fg, background) >= 3.5, child.hl.fg)
        end
    end)

    it('keeps semantic section background cache separate across repair options', function()
        local function section_bg(tolerance)
            local debug = statuesque.render(
                statuesque.compose({
                    {
                        { text = 'ACP', hl = { fg = '#61AFEF' } },
                        { text = ' pending', hl = { fg = '#61AFEF' } },
                    },
                }, {
                    surface = 'statusline',
                    segment_layout = 'gapped',
                    sigil = '',
                    mode_style = false,
                    palette = { '#003f7f' },
                    palette_distance_tolerance = tolerance,
                    base = { fg = '#ffffff', bg = '#8a5f75' },
                    outer = { fg = '#ffffff', bg = '#f7768e' },
                    inner = { fg = '#ffffff', bg = '#f7768e' },
                }),
                'debug'
            )

            for _, node in ipairs(debug) do
                if node.role == 'section' then
                    return node.hl.bg
                end
            end
        end

        local strict = section_bg(1)
        local permissive = section_bg(200)

        assert_equal(strict, '#8a5f75')
        assert_equal(permissive, '#f7768e')
    end)

    it('uses palette colors as candidates for aggregate semantic repairs', function()
        local background = '#f7768e'
        local debug = statuesque.render(
            statuesque.compose({
                {
                    { text = 'ACP', hl = { fg = '#61AFEF' } },
                },
            }, {
                surface = 'statusline',
                segment_layout = 'adjacent',
                sigil = '',
                mode_style = false,
                palette = {
                    '#003f7f',
                    '#ffffff',
                },
                outer = { fg = '#ffffff', bg = background },
                inner = { fg = '#ffffff', bg = background },
            }),
            'debug'
        )

        assert_equal(debug[1].children[1].hl.fg, '#003f7f')
    end)

    it('derives the default palette from common highlight groups', function()
        vim.api.nvim_set_hl(0, 'String', { fg = '#f8c97a' })

        local matched = style.match_palette_color('#f8c97a', '#101010')

        assert_equal(matched, '#f8c97a')
    end)

    it('uses the exact devicon color for filename filetype icons', function()
        local previous_devicons = package.loaded['nvim-web-devicons']
        package.loaded['nvim-web-devicons'] = {
            get_icon_color_by_filetype = function()
                return '', '#51a0cf'
            end,
        }

        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.bo[bufnr].filetype = 'lua'
        local debug = statuesque.render(
            statuesque.compose({ { text = 'OK' }, { name = 'filename', opts = { filetype_icon = true } } }, {
                surface = 'window_label',
                style = 'capsule',
                placement = { vertical = 'bottom' },
                sigil = '',
            }),
            'debug',
            { bufnr = bufnr }
        )

        local function find_role(nodes, role)
            for _, node in ipairs(nodes or {}) do
                if node.role == role then
                    return node
                end
                local found = find_role(node.children, role)
                if found ~= nil then
                    return found
                end
            end
            return nil
        end

        local icon = find_role(debug, 'filetype-icon')
        local filename = find_role(debug, 'filename')
        assert_equal(icon.exact_highlight, true)
        assert_equal(icon.hl.fg, '#51a0cf')
        assert(icon.hl.bg ~= '#7aa2f7', ('expected exact icon to darken background, got %s'):format(icon.hl.bg))
        assert_equal(filename.children[2].text, ' ')
        assert_equal(filename.children[3].role, 'filename')

        local incline = statuesque.render(
            statuesque.compose({ { text = 'OK' }, { name = 'filename', opts = { filetype_icon = true } } }, {
                surface = 'window_label',
                style = 'slanted',
                placement = { vertical = 'bottom' },
                side = 'right',
                sigil = '',
            }),
            'incline',
            { bufnr = bufnr, winid = 17 }
        )
        local roles = {}
        for index, chunk in ipairs(incline) do
            if type(chunk) == 'table' and type(chunk.statuesque) == 'table' then
                roles[chunk.statuesque.role] = roles[chunk.statuesque.role] or index
            end
        end

        assert(
            roles['segment-leading-separator-chrome-outer-glyph']
                < roles['segment-leading-separator-chrome-inner-glyph']
        )
        assert(roles['segment-leading-separator-chrome-inner-glyph'] < roles['filetype-icon'])

        package.loaded['nvim-web-devicons'] = previous_devicons
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('lets the default preset drive the window-label surface through incline', function()
        local previous_incline = package.loaded.incline
        local setup_opts
        package.loaded.incline = {
            setup = function(opts)
                setup_opts = opts
            end,
        }

        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(bufnr, ('/tmp/statuesque-incline-label-%d.lua'):format(bufnr))
        vim.bo[bufnr].filetype = 'lua'

        require('statuesque.presets.default').install({
            preset = {
                'default',
                opts = {
                    tabulature = false,
                },
            },
            surfaces = {
                window_label = {
                    placement = {
                        vertical = 'top',
                    },
                    backend = {
                        name = 'incline',
                        opts = {
                            window = {
                                zindex = 1,
                            },
                        },
                    },
                },
            },
        })

        local rendered = setup_opts.render({ winid = vim.api.nvim_get_current_win(), buf = bufnr })

        package.loaded.incline = previous_incline
        vim.api.nvim_buf_delete(bufnr, { force = true })

        assert_equal(setup_opts.window.zindex, 1)
        assert_equal(setup_opts.window.placement.horizontal, 'right')
        assert_equal(setup_opts.window.placement.vertical, 'top')
        assert_equal(setup_opts.window.margin.horizontal.right, 0)
        assert_equal(setup_opts.window.padding.right, 0)
        assert_contains(vim.inspect(rendered), ('statuesque-incline-label-%d.lua'):format(bufnr))
    end)

    it('lets top-level window-label config drive default preset placement', function()
        local previous_incline = package.loaded.incline
        local setup_opts
        package.loaded.incline = {
            setup = function(opts)
                setup_opts = opts
            end,
        }

        require('statuesque.presets.default').install({
            preset = {
                'default',
                opts = {
                    tabulature = false,
                },
            },
            window_label = {
                placement = {
                    vertical = 'top',
                },
            },
        })

        package.loaded.incline = previous_incline

        assert_equal(setup_opts.window.placement.vertical, 'top')
    end)

    it('regression: restores and can reinstall the Incline refresh wrapper', function()
        local integration = require('statuesque.integrations.incline')
        integration.disable()
        local previous_incline = package.loaded.incline
        local refresh_calls = 0
        local disable_calls = 0
        local original_refresh = function(value)
            refresh_calls = refresh_calls + 1
            return value
        end
        local incline = {
            setup = function() end,
            disable = function()
                disable_calls = disable_calls + 1
            end,
            refresh = original_refresh,
        }
        package.loaded.incline = incline

        assert_equal(integration.setup({}, 'regression-incline'), true)
        local first_wrapper = incline.refresh
        assert(first_wrapper ~= original_refresh)
        assert_equal(incline.refresh('first'), 'first')
        integration.disable()
        assert_equal(incline.refresh, original_refresh)

        assert_equal(integration.setup({}, 'regression-incline'), true)
        assert(incline.refresh ~= original_refresh)
        assert(incline.refresh ~= first_wrapper)
        assert_equal(incline.refresh('second'), 'second')
        integration.disable()
        assert_equal(incline.refresh, original_refresh)
        assert_equal(disable_calls, 2)
        assert(refresh_calls >= 4)

        package.loaded.incline = previous_incline
    end)

    it('keeps downstream Incline refresh wrappers callable and unwraps when exposed', function()
        local integration = require('statuesque.integrations.incline')
        integration.disable()
        local previous_incline = package.loaded.incline
        local refresh_calls = 0
        local original_refresh = function(value)
            refresh_calls = refresh_calls + 1
            return value, nil, 'tail'
        end
        local incline = {
            setup = function() end,
            disable = function() end,
            refresh = original_refresh,
        }
        package.loaded.incline = incline

        assert_equal(integration.setup({}, 'regression-incline-chain'), true)
        local statuesque_wrapper = incline.refresh
        local downstream_wrapper = function(...)
            return statuesque_wrapper(...)
        end
        incline.refresh = downstream_wrapper

        integration.disable()
        assert_equal(incline.refresh, downstream_wrapper)
        local ok, first, middle, tail = pcall(incline.refresh, 'downstream')
        assert_equal(ok, true)
        assert_equal(first, 'downstream')
        assert_equal(middle, nil)
        assert_equal(tail, 'tail')

        incline.refresh = statuesque_wrapper
        integration.disable()
        assert_equal(incline.refresh, original_refresh)
        assert(refresh_calls >= 2)
        package.loaded.incline = previous_incline
    end)

    it('composes right-sided incline preset surfaces without a fake left sigil', function()
        local surfaces = require('statuesque.presets.default').surfaces({
            preset = false,
            surfaces = {
                window_label = {
                    right = {
                        { text = 'omega' },
                    },
                    sigil = 'S',
                    backend = {
                        name = 'incline',
                    },
                },
            },
        })
        local debug = statuesque.render(surfaces.window_label, 'debug')

        assert_equal(debug[1].role, 'segment-leading-separator')
        assert_equal(debug[2].children[1].text, 'omega')
        assert_equal(debug[3].role, 'sigil-trailing-separator')
        assert_equal(debug[4].role, 'sigil-leading-separator')
        assert_equal(debug[#debug].role, 'sigil')
        assert_equal(debug[#debug].text, ' S  ')
    end)

    it('disables winbar and window-label sigils in the default preset', function()
        local surfaces = require('statuesque.presets.default').surfaces({
            preset = {
                'default',
                opts = {
                    tabulature = false,
                },
            },
            surfaces = {
                winbar = {
                    left = {
                        { text = 'crumb' },
                    },
                },
                window_label = {
                    right = {
                        { text = 'label' },
                    },
                },
            },
        })

        local winbar = statuesque.render(surfaces.winbar, 'debug')
        local window_label = statuesque.render(surfaces.window_label, 'debug')

        assert(winbar[1] == nil or winbar[1].role ~= 'sigil')
        assert(window_label[1] == nil or window_label[#window_label].role ~= 'sigil')
    end)

    it('rejects backend placements not supported by target metadata', function()
        local ok, err = pcall(function()
            require('statuesque.presets.default').surfaces({
                preset = false,
                surfaces = {
                    status = {
                        left = { 'status' },
                        placement = {
                            vertical = 'top',
                        },
                        backend = {
                            name = 'statusline',
                        },
                    },
                },
            })
        end)

        assert_equal(ok, false)
        assert_contains(err, 'does not support vertical placement top')
    end)

    it('rejects incline surfaces with both left and right widget runs', function()
        local ok, err = pcall(function()
            require('statuesque.presets.default').surfaces({
                preset = false,
                surfaces = {
                    window_label = {
                        left = { 'left' },
                        right = { 'right' },
                        backend = 'incline',
                    },
                },
            })
        end)

        assert_equal(ok, false)
        assert_contains(err, 'cannot define both left and right for incline backend')
    end)

    it('rejects multiple surfaces targeting the same backend target', function()
        local ok, err = pcall(function()
            require('statuesque.presets.default').surfaces({
                preset = false,
                surfaces = {
                    one = {
                        left = { 'one' },
                        backend = 'statusline',
                    },
                    two = {
                        left = { 'two' },
                        backend = 'statusline',
                    },
                },
            })
        end)

        assert_equal(ok, false)
        assert_contains(err, 'both render to backend statusline target statusline')
    end)

    it('rejects backend targets unless capabilities explicitly allow them', function()
        local ok, err = pcall(function()
            require('statuesque.presets.default').surfaces({
                preset = false,
                surfaces = {
                    status = {
                        left = { 'status' },
                        backend = {
                            name = 'statusline',
                            target = 'statusline',
                        },
                    },
                },
            })
        end)

        assert_equal(ok, false)
        assert_contains(err, 'backend statusline does not support target statusline')
    end)

    it('allows backend targets declared by backend capabilities', function()
        package.loaded['statuesque.backend.targeted_backend'] = nil
        package.preload['statuesque.backend.targeted_backend'] = function()
            return {
                capabilities = {
                    targets = { 'statusline' },
                },
                render = function(render_spec)
                    return statuesque.render(render_spec, 'text')
                end,
            }
        end

        local surfaces = require('statuesque.presets.default').surfaces({
            preset = false,
            surfaces = {
                status = {
                    left = { 'status' },
                    backend = {
                        name = 'targeted_backend',
                        target = 'statusline',
                    },
                },
            },
        })

        package.preload['statuesque.backend.targeted_backend'] = nil
        package.loaded['statuesque.backend.targeted_backend'] = nil

        assert_contains(statuesque.render(surfaces.status, 'text'), 'status')
    end)

    it('isolates cached Incline table output from consumer mutation', function()
        local cached = {
            id = 'cached-incline-table',
            cache = { key = 'cached-incline-table' },
            render = function()
                return {
                    id = 'cached-incline-table-node',
                    role = 'demo',
                    hl = 'StatuesqueDemo',
                    text = 'demo',
                }
            end,
        }

        local first = statuesque.render({ cached }, 'incline')
        first[1][1] = 'mutated'
        first[1].statuesque.role = 'mutated'

        local second = statuesque.render({ cached }, 'incline')

        assert_equal(second[1][1], 'demo')
        assert_equal(second[1].statuesque.role, 'demo')
    end)

    it('builds and installs statusline-family surface expressions', function()
        statuesque.set_surface('status', { 'ready' })

        assert_equal(
            statuesque.surface_expression('status', 'statusline'),
            '%!v:lua.require\'statuesque\'.render_installed_surface("status", "statusline")'
        )

        statuesque.install_surface('status', 'statusline')

        assert_equal(vim.o.laststatus, 3)
        assert_equal(vim.o.statusline, '%!v:lua.require\'statuesque\'.render_installed_surface("status", "statusline")')

        vim.o.laststatus = 2
        statuesque.install_surface('status', 'statusline')
        assert_equal(vim.o.laststatus, 3)
    end)

    it('renders installed winbars with Neovim window and buffer context', function()
        local winid = vim.api.nvim_get_current_win()
        local bufnr = vim.api.nvim_get_current_buf()
        local previous_statusline_winid = vim.g.statusline_winid
        vim.g.statusline_winid = winid

        statuesque.set_surface('context-winbar', function(context)
            return ('%s:%s'):format(context.winid, context.bufnr)
        end)

        assert_equal(statuesque.render_installed_surface('context-winbar', 'winbar'), ('%s:%s'):format(winid, bufnr))
        vim.g.statusline_winid = previous_statusline_winid
    end)

    it('replaces window-local render targets only while the owner buffer is visible', function()
        local winid = vim.api.nvim_get_current_win()
        local owner_bufnr = vim.api.nvim_create_buf(true, false)
        local other_bufnr = vim.api.nvim_create_buf(true, false)
        local previous_winbar = vim.o.winbar

        vim.o.winbar = 'ambient-winbar'
        vim.api.nvim_win_set_buf(winid, owner_bufnr)

        local updated = statuesque.replace_window_surface({
            owner = 'fixture',
            target = 'winbar',
            winid = winid,
            bufnr = owner_bufnr,
            expression = 'owned-winbar',
        })

        assert_equal(updated[1], winid)
        assert_equal(vim.wo[winid].winbar, 'owned-winbar')

        vim.api.nvim_win_set_buf(winid, other_bufnr)
        vim.api.nvim_exec_autocmds('BufWinEnter', {
            buffer = other_bufnr,
            modeline = false,
        })

        assert_equal(vim.wo[winid].winbar, 'ambient-winbar')
        vim.o.winbar = previous_winbar
    end)

    it('clears an explicitly replaced window-local render target', function()
        local winid = vim.api.nvim_get_current_win()
        local owner_bufnr = vim.api.nvim_create_buf(true, false)
        local previous_winbar = vim.o.winbar

        vim.o.winbar = 'ambient-winbar'
        vim.api.nvim_win_set_buf(winid, owner_bufnr)
        statuesque.replace_window_surface({
            owner = 'fixture',
            target = 'winbar',
            winid = winid,
            bufnr = owner_bufnr,
            expression = 'owned-winbar',
        })

        statuesque.clear_window_surface(winid, 'winbar')

        assert_equal(vim.wo[winid].winbar, 'ambient-winbar')
        vim.o.winbar = previous_winbar
    end)

    it('regression: restores the exact pre-existing window-local surface value', function()
        vim.cmd('split')
        local winid = vim.api.nvim_get_current_win()
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_set_option_value('winbar', 'local-before-statuesque', { win = winid })

        statuesque.replace_window_surface({
            owner = 'regression',
            target = 'winbar',
            winid = winid,
            bufnr = bufnr,
            expression = 'owned-by-statuesque',
        })
        statuesque.clear_window_surface(winid, 'winbar')

        assert_equal(vim.api.nvim_get_option_value('winbar', { win = winid }), 'local-before-statuesque')
        vim.api.nvim_win_close(winid, true)
    end)

    it('restores inherited window-local surface state instead of freezing the old global value', function()
        local previous_global = vim.api.nvim_get_option_value('winbar', { scope = 'global' })
        vim.cmd('split')
        local winid = vim.api.nvim_get_current_win()
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_set_option_value('winbar', 'global-before-replacement', { scope = 'global' })
        vim.api.nvim_set_option_value('winbar', '', { win = winid, scope = 'local' })

        statuesque.replace_window_surface({
            owner = 'regression-inherited',
            target = 'winbar',
            winid = winid,
            bufnr = bufnr,
            expression = 'owned-by-statuesque',
        })
        vim.api.nvim_set_option_value('winbar', 'global-after-replacement', { scope = 'global' })
        statuesque.clear_window_surface(winid, 'winbar')

        assert_equal(vim.api.nvim_get_option_value('winbar', { win = winid, scope = 'local' }), '')
        assert_equal(vim.api.nvim_get_option_value('winbar', { win = winid }), 'global-after-replacement')
        vim.api.nvim_win_close(winid, true)
        vim.api.nvim_set_option_value('winbar', previous_global, { scope = 'global' })
    end)

    it('can replace a window-local render target for all windows displaying a buffer', function()
        local first_win = vim.api.nvim_get_current_win()
        local owner_bufnr = vim.api.nvim_create_buf(true, false)
        local previous_winbar = vim.o.winbar

        vim.o.winbar = 'ambient-winbar'
        vim.api.nvim_win_set_buf(first_win, owner_bufnr)
        vim.cmd('split')
        local second_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(second_win, owner_bufnr)

        local updated = statuesque.replace_window_surface({
            owner = 'fixture',
            target = 'winbar',
            bufnr = owner_bufnr,
            expression = 'owned-winbar',
            all_windows = true,
        })

        table.sort(updated)

        assert_equal(#updated, 2)
        assert_equal(updated[1], math.min(first_win, second_win))
        assert_equal(updated[2], math.max(first_win, second_win))
        assert_equal(vim.wo[first_win].winbar, 'owned-winbar')
        assert_equal(vim.wo[second_win].winbar, 'owned-winbar')

        vim.cmd('close')
        vim.o.winbar = previous_winbar
    end)

    it('routes custom render targets through runtimepath backend discovery', function()
        package.loaded['statuesque.backend.demo_backend'] = nil
        package.preload['statuesque.backend.demo_backend'] = function()
            return {
                render = function(render_spec)
                    return 'demo:' .. statuesque.render(render_spec, 'text')
                end,
            }
        end

        assert_equal(statuesque.render({ 'ok' }, 'demo_backend'), 'demo:ok')

        package.preload['statuesque.backend.demo_backend'] = nil
        package.loaded['statuesque.backend.demo_backend'] = nil
    end)

    it('loads custom backend modules from runtimepath-style lua paths', function()
        package.loaded['statuesque.backend.runtime_fixture'] = nil

        with_runtimepath('tests/fixtures/runtime-backend', function()
            assert_equal(statuesque.render({ 'ok' }, 'runtime_fixture'), 'runtime-fixture:ok')

            local capabilities = statuesque.backend_capabilities('runtime_fixture')
            assert_equal(capabilities.target, 'runtime_fixture')
            assert_equal(capabilities.fixture, true)
            assert_equal(capabilities.raw, true)
            assert_equal(capabilities.install, false)
            assert_equal(capabilities.render_scope, 'global')
            assert_equal(capabilities.hover, false)
            assert_equal(capabilities.hover_degradation, 'metadata')
        end)

        package.loaded['statuesque.backend.runtime_fixture'] = nil
    end)

    it('exposes built-in backend capabilities', function()
        local debug = statuesque.backend_capabilities('debug')
        local vim_target = statuesque.backend_capabilities('vim')
        local statusline = statuesque.backend_capabilities('statusline')
        local tabline = statuesque.backend_capabilities('tabline')
        local winbar = statuesque.backend_capabilities('winbar')
        local text = statuesque.backend_capabilities('text')
        local incline = statuesque.backend_capabilities('incline')

        assert_equal(debug.target, 'debug')
        assert_equal(debug.snapshot, true)
        assert_equal(debug.highlights, 'preserved')
        assert_equal(debug.hover, 'preserved')
        assert_equal(vim_target.target, 'vim')
        assert_equal(vim_target.highlights, true)
        assert_equal(vim_target.clicks, true)
        assert_equal(vim_target.hover, 'registered')
        assert_equal(vim_target.hover_degradation, 'requires_surface_hit_testing')
        assert_equal(statusline.target, 'statusline')
        assert_equal(statusline.highlights, true)
        assert_equal(statusline.clicks, true)
        assert_equal(statusline.hover, 'registered')
        assert_equal(statusline.align, true)
        assert_equal(statusline.install, true)
        assert_equal(statusline.global_statusline, true)
        assert_equal(statusline.render_scope, 'global')
        assert_equal(statusline.placement.vertical, 'bottom')
        assert_equal(tabline.target, 'tabline')
        assert_equal(tabline.install, true)
        assert_equal(tabline.render_scope, 'global')
        assert_equal(tabline.placement.vertical, 'top')
        assert_equal(winbar.target, 'winbar')
        assert_equal(winbar.install, true)
        assert_equal(winbar.render_scope, 'window')
        assert_equal(winbar.window_context, true)
        assert_equal(winbar.buffer_context, true)
        assert_equal(winbar.placement.vertical, 'top')
        assert_equal(text.highlights, false)
        assert_equal(text.clicks, false)
        assert_equal(text.hover, false)
        assert_equal(text.render_scope, 'global')
        assert_equal(incline.render_scope, 'window')
        assert_equal(incline.window_context, true)
        assert_equal(incline.buffer_context, true)
        assert_equal(incline.highlights, 'groups')
        assert_equal(incline.clicks, false)
        assert_equal(incline.click_degradation, 'metadata')
        assert_equal(incline.hover, false)
        assert_equal(incline.hover_degradation, 'metadata')
        assert_equal(incline.placement.vertical.top, true)
        assert_equal(incline.placement.vertical.bottom, true)
    end)

    it('preserves custom backend capabilities', function()
        package.loaded['statuesque.backend.capability_demo'] = nil
        package.preload['statuesque.backend.capability_demo'] = function()
            return {
                capabilities = {
                    highlights = true,
                    clicks = false,
                    custom_surface = true,
                },
                render = function(render_spec)
                    return statuesque.render(render_spec, 'text')
                end,
            }
        end

        local capabilities = statuesque.backend_capabilities('capability_demo')

        package.preload['statuesque.backend.capability_demo'] = nil
        package.loaded['statuesque.backend.capability_demo'] = nil

        assert_equal(capabilities.target, 'capability_demo')
        assert_equal(capabilities.highlights, true)
        assert_equal(capabilities.clicks, false)
        assert_equal(capabilities.custom_surface, true)
    end)

    it('documents the runtime backend authoring contract', function()
        local readme = table.concat(vim.fn.readfile('README.md'), '\n')

        assert_contains(readme, '## Backend Authoring')
        assert_contains(readme, 'render(render_spec, opts)')
        assert_contains(readme, 'capabilities')
        assert_contains(readme, 'render_scope')
        assert_contains(readme, 'window_context')
        assert_contains(readme, 'buffer_context')
        assert_contains(readme, 'highlights')
        assert_contains(readme, 'clicks')
        assert_contains(readme, 'hover')
        assert_contains(readme, 'click_degradation')
        assert_contains(readme, 'hover_degradation')
        assert_contains(readme, 'raw')
        assert_contains(readme, 'align')
        assert_contains(readme, 'install')
        assert_contains(readme, 'degradation_metadata')
    end)

    it('makes text target degradation match its declared capabilities', function()
        local capabilities = statuesque.backend_capabilities('text')
        local clicked = false
        local rendered = statuesque.render({
            {
                text = 'left',
                hl = 'StatuesqueModeNormal',
                on_click = function()
                    clicked = true
                end,
            },
            { align = 'right' },
            { text = 'right' },
        }, 'text')

        assert_equal(capabilities.highlights, false)
        assert_equal(capabilities.clicks, false)
        assert_equal(capabilities.hover, false)
        assert_equal(capabilities.align, false)
        assert_equal(rendered, 'leftright')
        assert_equal(clicked, false)
    end)

    it('restores owned options when setup disables a surface', function()
        statuesque.setup({ manifold = false, preset = false, surfaces = {} })
        vim.o.statusline = 'ambient-statusline'
        vim.o.laststatus = 2

        statuesque.setup({
            manifold = false,
            preset = false,
            surfaces = {
                statusline = {
                    left = { { text = 'owned' } },
                },
            },
        })
        assert_equal(vim.o.laststatus, 3)
        assert_contains(vim.o.statusline, 'render_installed_surface')

        statuesque.setup({
            manifold = false,
            preset = false,
            surfaces = {
                statusline = false,
            },
        })
        assert_equal(vim.o.statusline, 'ambient-statusline')
        assert_equal(vim.o.laststatus, 2)
    end)

    it('keeps the working installation when setup validation fails', function()
        local previous_statusline = vim.o.statusline
        local previous_laststatus = vim.o.laststatus
        statuesque.setup({ manifold = false, preset = false, surfaces = {} })
        vim.o.statusline = 'transaction-ambient'
        vim.o.laststatus = 2
        statuesque.setup({
            manifold = false,
            preset = false,
            surfaces = {
                statusline = {
                    left = { { text = 'working-installation' } },
                },
            },
        })
        local installed_expression = vim.o.statusline

        local ok = pcall(statuesque.setup, {
            manifold = false,
            preset = false,
            surfaces = {
                statusline = {},
            },
        })

        assert_equal(ok, false)
        assert_equal(vim.o.statusline, installed_expression)
        assert_equal(vim.o.laststatus, 3)
        assert_contains(statuesque.render_surface('statusline', 'text'), 'working-installation')

        statuesque.setup({ manifold = false, preset = false, surfaces = {} })
        vim.o.statusline = previous_statusline
        vim.o.laststatus = previous_laststatus
    end)

    it('rolls back the working installation when backend setup fails', function()
        local previous_statusline = vim.o.statusline
        local previous_laststatus = vim.o.laststatus
        local previous_incline = package.loaded.incline
        statuesque.setup({ manifold = false, preset = false, surfaces = {} })
        vim.o.statusline = 'rollback-ambient'
        vim.o.laststatus = 2
        statuesque.setup({
            manifold = false,
            preset = false,
            surfaces = {
                statusline = {
                    left = { { text = 'rollback-working' } },
                },
            },
        })
        local installed_expression = vim.o.statusline
        package.loaded.incline = {
            disable = function() end,
            refresh = function() end,
            setup = function()
                error('forced Incline setup failure')
            end,
        }

        local ok = pcall(statuesque.setup, {
            manifold = false,
            preset = false,
            surfaces = {
                window_label = {
                    right = { { text = 'fails-to-install' } },
                    backend = { name = 'incline' },
                },
            },
        })

        assert_equal(ok, false)
        assert_equal(vim.o.statusline, installed_expression)
        assert_equal(vim.o.laststatus, 3)
        assert_contains(statuesque.render_surface('statusline', 'text'), 'rollback-working')

        package.loaded.incline = previous_incline
        statuesque.setup({ manifold = false, preset = false, surfaces = {} })
        vim.o.statusline = previous_statusline
        vim.o.laststatus = previous_laststatus
    end)

    it('regression: restores setup options independently according to ownership', function()
        local previous_statusline = vim.o.statusline
        local previous_laststatus = vim.o.laststatus
        statuesque.setup({ manifold = false, preset = false, surfaces = {} })
        vim.o.statusline = 'ambient-primary'
        vim.o.laststatus = 2

        statuesque.setup({
            manifold = false,
            preset = false,
            surfaces = {
                statusline = { left = { { text = 'owned' } } },
            },
        })
        vim.o.statusline = 'user-primary'
        statuesque.setup({
            manifold = false,
            preset = false,
            surfaces = { statusline = false },
        })
        assert_equal(vim.o.statusline, 'user-primary')
        assert_equal(vim.o.laststatus, 2)

        vim.o.statusline = 'ambient-primary-two'
        vim.o.laststatus = 2
        statuesque.setup({
            manifold = false,
            preset = false,
            surfaces = {
                statusline = { left = { { text = 'owned-again' } } },
            },
        })
        vim.o.laststatus = 1
        statuesque.setup({
            manifold = false,
            preset = false,
            surfaces = { statusline = false },
        })
        assert_equal(vim.o.statusline, 'ambient-primary-two')
        assert_equal(vim.o.laststatus, 1)

        vim.o.statusline = previous_statusline
        vim.o.laststatus = previous_laststatus
    end)

    it('invalidates rendered caches on colorscheme changes', function()
        local calls = 0
        local cached = {
            cache = { key = 'colorscheme-cache' },
            render = function()
                calls = calls + 1
                return 'cached'
            end,
        }
        statuesque.setup({ manifold = false })
        statuesque.render({ cached }, 'statusline')
        statuesque.render({ cached }, 'statusline')
        assert_equal(calls, 1)

        vim.api.nvim_exec_autocmds('ColorScheme', { modeline = false })
        statuesque.render({ cached }, 'statusline')
        assert_equal(calls, 2)
    end)

    it('installs the default preset on demand without manifold wiring', function()
        statuesque.setup({
            manifold = false,
            preset = 'default',
            surfaces = {
                statusline = {
                    sigil = 'S',
                },
            },
        })

        assert_equal(vim.o.laststatus, 3)
        assert_equal(
            vim.o.statusline,
            '%!v:lua.require\'statuesque\'.render_installed_surface("statusline", "statusline")'
        )
        assert_equal(vim.o.tabline, '%!v:lua.require\'statuesque\'.render_installed_surface("tabline", "tabline")')
        assert_equal(vim.o.winbar, '%!v:lua.require\'statuesque\'.render_installed_surface("winbar", "winbar")')
        assert(statuesque.render_surface('statusline', 'text'):find('S', 1, true))
    end)

    it('uses real Tabulature state render specs in the default tabline when available', function()
        local tabulature_path = vim.env.TABULATURE_NVIM_PATH or '../tabulature.nvim'
        assert(vim.fn.isdirectory(tabulature_path) == 1, 'TABULATURE_NVIM_PATH is not a plugin checkout')

        with_runtimepath(tabulature_path, function()
            package.loaded['tabulature'] = nil
            package.loaded['tabulature.state'] = nil
            package.loaded['tabulature.render.statuesque'] = nil
            package.loaded['statuesque.widgets.tabulature'] = nil
            local previous_tabulature = package.preload['tabulature']
            local previous_state = package.preload['tabulature.state']
            local previous_renderer = package.preload['tabulature.render.statuesque']
            package.preload['tabulature'] = function()
                return {}
            end
            package.preload['tabulature.state'] = function()
                return {
                    to_tree = function()
                        return {
                            kind = 'workspace',
                            children = {
                                {
                                    id = 'alpha',
                                    kind = 'tab',
                                    label = 'Alpha',
                                    active = true,
                                    children = {},
                                },
                            },
                        }
                    end,
                }
            end
            package.preload['tabulature.render.statuesque'] = function()
                return {
                    to_spec = function(root)
                        assert_equal(root.children[1].label, 'Alpha')
                        return {
                            {
                                text = 'Alpha',
                                role = 'tab',
                            },
                        }
                    end,
                }
            end

            local surfaces = require('statuesque.presets.default').surfaces()
            local rendered = statuesque.render(surfaces.tabline, 'text')

            package.loaded['tabulature'] = nil
            package.loaded['tabulature.state'] = nil
            package.loaded['tabulature.render.statuesque'] = nil
            package.loaded['statuesque.widgets.tabulature'] = nil
            package.preload['tabulature'] = previous_tabulature
            package.preload['tabulature.state'] = previous_state
            package.preload['tabulature.render.statuesque'] = previous_renderer

            assert(rendered:find('𝄞', 1, true), rendered)
            assert(rendered:find('Alpha', 1, true), rendered)
        end)
    end)

    it('loads external default widgets from runtimepath modules', function()
        with_runtimepath('tests/fixtures/widget-module', function()
            package.loaded['statuesque.widgets.git_repo'] = nil
            local surfaces = require('statuesque.presets.default').surfaces({
                preset = {
                    'default',
                    opts = {
                        tabulature = false,
                        git_repo = {
                            icon = 'G',
                        },
                    },
                },
                surfaces = {
                    statusline = {
                        sigil = '',
                    },
                },
            })
            local rendered = statuesque.render(surfaces.statusline, 'text')

            package.loaded['statuesque.widgets.git_repo'] = nil

            assert_contains(rendered, 'G external-repo')
        end)
    end)

    it('renders breadcrumbs from buffer-local producer state', function()
        local bufnr = vim.api.nvim_get_current_buf()
        vim.b[bufnr].statuesque_breadcrumbs = {
            'Module',
            { text = 'Function' },
        }

        local rendered = statuesque.render({
            name = 'breadcrumbs',
            opts = {
                separator = ' / ',
            },
        }, 'winbar', { bufnr = bufnr })

        vim.b[bufnr].statuesque_breadcrumbs = nil

        assert_equal(rendered, 'Module / Function')
    end)

    it('renders breadcrumbs from nvim-navic when available', function()
        local previous_navic = package.loaded['nvim-navic']
        local seen_bufnr
        package.loaded['nvim-navic'] = {
            is_available = function(bufnr)
                seen_bufnr = bufnr
                return true
            end,
            get_location = function(opts)
                return 'Root' .. opts.separator .. 'Leaf'
            end,
        }

        local bufnr = vim.api.nvim_get_current_buf()
        local rendered = statuesque.render({
            name = 'breadcrumbs',
            opts = {
                separator = ' > ',
            },
        }, 'winbar', { bufnr = bufnr })

        package.loaded['nvim-navic'] = previous_navic

        assert_equal(seen_bufnr, bufnr)
        assert_equal(rendered, 'Root > Leaf')
    end)

    it('attaches nvim-navic to existing document-symbol LSP clients', function()
        local previous_navic = package.loaded['nvim-navic']
        local previous_get_clients = vim.lsp.get_clients
        local bufnr = vim.api.nvim_get_current_buf()
        local attached = {}

        package.loaded['nvim-navic'] = {
            attach = function(client, attach_bufnr)
                attached[#attached + 1] = { client = client, bufnr = attach_bufnr }
            end,
            is_available = function()
                return true
            end,
            get_location = function()
                return 'Root > Leaf'
            end,
        }
        vim.lsp.get_clients = function(opts)
            assert_equal(opts.bufnr, bufnr)
            return {
                {
                    id = 997,
                    name = 'symbols',
                    server_capabilities = {
                        documentSymbolProvider = true,
                    },
                },
                {
                    id = 998,
                    name = 'no-symbols',
                    server_capabilities = {},
                },
            }
        end

        local rendered = statuesque.render({
            name = 'breadcrumbs',
        }, 'winbar', { bufnr = bufnr })

        package.loaded['nvim-navic'] = previous_navic
        vim.lsp.get_clients = previous_get_clients

        assert_equal(rendered, 'Root > Leaf')
        assert_equal(#attached, 1)
        assert_equal(attached[1].client.name, 'symbols')
        assert_equal(attached[1].bufnr, bufnr)
    end)

    it('renders default preset surfaces with distinct visual responsibilities', function()
        local previous_navic = package.loaded['nvim-navic']
        local previous_dap = package.loaded.dap
        package.loaded['nvim-navic'] = {
            is_available = function()
                return true
            end,
            get_location = function()
                return 'Module > Function'
            end,
        }
        package.loaded.dap = {
            session = function()
                return {
                    config = {
                        name = 'Debug Demo',
                    },
                }
            end,
            status = function()
                return 'stopped'
            end,
        }
        vim.fn.setqflist({}, 'r', {
            items = {
                {
                    filename = '/tmp/statuesque-default-quickfix.lua',
                    lnum = 7,
                    col = 1,
                    text = 'default quickfix item',
                },
            },
        })

        local surfaces = require('statuesque.presets.default').surfaces({
            preset = {
                'default',
                opts = {
                    tabulature = false,
                },
            },
            surfaces = {
                statusline = { sigil = 'S' },
                tabline = { sigil = 'T' },
                winbar = { sigil = 'W' },
            },
        })

        local statusline = statuesque.render(surfaces.statusline, 'text', { mode = 'normal' })
        local tabline = statuesque.render(surfaces.tabline, 'text')
        local winbar = statuesque.render(surfaces.winbar, 'text')

        package.loaded['nvim-navic'] = previous_navic
        package.loaded.dap = previous_dap
        vim.fn.setqflist({}, 'r')

        assert(statusline:find('S', 1, true), statusline)
        assert(statusline:find('NORMAL', 1, true), statusline)
        assert(not statusline:find('[No Name]', 1, true), statusline)
        assert(statusline:find('QF 1/1', 1, true), statusline)
        assert(statusline:find(' stopped Debug Demo', 1, true), statusline)
        assert(statusline:find('utf-8 unix', 1, true), statusline)
        assert(tabline:find('T', 1, true), tabline)
        assert(tabline:find('statuesque.nvim', 1, true), tabline)
        assert(winbar:find('W', 1, true), winbar)
        assert(winbar:find('Module > Function', 1, true), winbar)
    end)

    it('uses gapped segment layout in the default preset', function()
        local surfaces = require('statuesque.presets.default').surfaces({
            preset = {
                'default',
                opts = {
                    tabulature = false,
                },
            },
            gap_padding = '',
            surfaces = {
                statusline = { sigil = '' },
                tabline = { sigil = '' },
                winbar = { sigil = '' },
            },
        })

        local statusline = statuesque.render(surfaces.statusline, 'debug', { mode = 'normal' })
        local tabline = statuesque.render(surfaces.tabline, 'debug')

        assert_equal(statusline[1].role, 'segment-leading-separator')
        assert_gapped_leading_separator(statusline[1], '')
        assert_equal(tabline[1].role, 'segment-leading-separator')
        assert_gapped_leading_separator(tabline[1], '')
    end)

    it('applies top-level visual options to preset surfaces', function()
        local surfaces = require('statuesque.presets.default').surfaces({
            preset = {
                'default',
                opts = {
                    tabulature = false,
                },
            },
            style = 'capsule',
            surfaces = {
                statusline = { sigil = '' },
            },
        })

        local debug = statuesque.render(surfaces.statusline, 'debug', { mode = 'normal' })

        assert_equal(debug[1].role, 'segment-leading-separator')
        assert_unpadded_separator(debug[1], '')
    end)

    it('lets surface overrides disable preset surfaces', function()
        local surfaces = require('statuesque.presets.default').surfaces({
            preset = {
                'default',
                opts = {
                    tabulature = false,
                },
            },
            surfaces = {
                winbar = {
                    enabled = false,
                },
            },
        })

        assert(surfaces.statusline ~= nil)
        assert_equal(surfaces.winbar, nil)
    end)

    it('rejects unnamed preset tables', function()
        local ok, err = pcall(function()
            require('statuesque.presets.default').surfaces({
                preset = {
                    opts = {
                        tabulature = false,
                    },
                },
            })
        end)

        assert_equal(ok, false)
        assert_contains(err, 'must name the preset as the first array item')
    end)

    it('fails explicitly for unsupported render and install targets', function()
        local render_ok, render_err = pcall(function()
            statuesque.render({ 'ready' }, 'floating-widget')
        end)
        local capability_ok, capability_err = pcall(function()
            statuesque.backend_capabilities('floating-widget')
        end)
        local install_ok, install_err = pcall(function()
            statuesque.install_surface('status', 'floating-widget')
        end)

        assert(not render_ok)
        assert(tostring(render_err):find('unsupported statuesque render target: floating-widget', 1, true))
        assert(not capability_ok)
        assert(tostring(capability_err):find('unsupported statuesque render target: floating-widget', 1, true))
        assert(not install_ok)
        assert(tostring(install_err):find('unsupported install target: floating-widget', 1, true))
    end)

    it('preserves backend module load failures instead of masking them', function()
        package.preload['statuesque.backend.exploding'] = function()
            error('backend load exploded')
        end

        local ok, err = pcall(function()
            statuesque.render({ 'ready' }, 'exploding')
        end)

        package.preload['statuesque.backend.exploding'] = nil

        assert(not ok)
        assert(tostring(err):find('backend load exploded', 1, true))
    end)

    it('fails explicitly when a runtimepath backend module violates the backend contract', function()
        package.loaded['statuesque.backend.malformed_fixture'] = nil

        local ok, err = with_runtimepath('tests/fixtures/runtime-backend', function()
            return pcall(function()
                statuesque.render({ 'ready' }, 'malformed_fixture')
            end)
        end)

        package.loaded['statuesque.backend.malformed_fixture'] = nil

        assert(not ok)
        assert(tostring(err):find('invalid statuesque backend "malformed_fixture"', 1, true))
        assert(tostring(err):find('expected table with render(spec, opts)', 1, true))
    end)
end)

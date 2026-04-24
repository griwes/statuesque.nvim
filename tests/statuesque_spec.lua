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

local function strip_vim_statusline(actual)
    return tostring(actual):gsub('%%#[^#]-#', ''):gsub('%%%*', '')
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
                text = 'click',
                on_click = function() end,
            },
        }, 'debug')

        assert_equal(debug[1].on_click, '<function>')
    end)

    it('renders plain text with truncation policies', function()
        assert_equal(statuesque.render({ text = 'abcdefgh', max_width = 5 }, 'text'), 'ab...')
        assert_equal(statuesque.render({ text = 'abcdefgh', max_width = 5, truncate = 'left' }, 'text'), '...gh')
        assert_equal(statuesque.render({ text = 'abcdefgh', max_width = 5, truncate = 'middle' }, 'text'), 'a...h')
        assert_equal(statuesque.render({ text = 'abcdefgh', max_width = 5, truncate = 'hide' }, 'text'), '')
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

        assert_equal(statuesque.render({ cached_separator }, 'incline', { side = 'left' })[1][1], '  ')
        assert_equal(statuesque.render({ cached_separator }, 'incline', { side = 'right' })[1][1], '  ')
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

    it('composes section-style bars with interpolated styles and explicit separators', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                { text = 'beta' },
            }, {
                surface = 'statusline',
                sigil = 'N',
                mode_style = false,
                outer = { fg = '#000000', bg = '#ffffff' },
                inner = { fg = '#ffffff', bg = '#000000' },
            }),
            'debug'
        )

        assert_equal(debug[1].role, 'sigil')
        assert_equal(debug[1].text, ' N')
        assert_equal(debug[1].hl.bg, '#ff9e64')
        assert_equal(debug[2].role, 'separator')
        assert_separator(debug[2], '')
        assert_equal(debug[3].children[1].text, 'alpha')
        assert_equal(debug[5].children[1].text, 'beta')
        assert_equal(debug[3].hl.bg, '#ffffff')
        assert_equal(debug[4].children[1].hl.bg, '#ffffff')
        assert_equal(debug[4].children[2].hl.fg, '#ffffff')
        assert_equal(debug[4].children[2].hl.bg, '#262626')
        assert_equal(debug[4].children[3].hl.bg, '#262626')
        assert_equal(debug[5].hl.bg, '#262626')

        assert_equal(statuesque.render({ { separator = 'inner' } }, 'text'), '  ')
    end)

    it('keeps interpolated section text readable on low-contrast palettes', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                { text = 'beta' },
                { text = 'gamma' },
            }, {
                surface = 'statusline',
                sigil = '',
                mode_style = false,
                outer = { fg = '#777777', bg = '#777777' },
                inner = { fg = '#222222', bg = '#222222' },
            }),
            'debug'
        )

        assert_equal(debug[1].hl.bg, '#777777')
        assert_equal(debug[1].hl.fg, '#000000')
        assert_equal(debug[3].hl.bg, '#535353')
        assert_equal(debug[3].hl.fg, '#c0caf5')
        assert_equal(debug[5].hl.bg, '#2f2f2f')
        assert_equal(debug[5].hl.fg, '#c0caf5')
    end)

    it('lets interpolation endpoints opt into the pure inner style', function()
        local debug = statuesque.render(
            statuesque.compose({
                { text = 'alpha' },
                { text = 'beta' },
            }, {
                surface = 'statusline',
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
        assert_equal(hl.fg, '#000000')
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
        assert_equal(debug[1].text, ' ')
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
        assert_equal(debug[5].hl.bg, '#262626')
        assert_equal(debug[6].children[1].hl.bg, '#262626')
        assert_equal(debug[6].children[2].hl.fg, '#ffffff')
        assert_equal(debug[6].children[2].hl.bg, '#262626')
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
                'Alpha',
            },
        }, 'incline')

        assert_equal(rendered[1][1], 'Alpha')
        assert_equal(rendered[1].group, 'StatuesqueTab')
        assert_equal(rendered[1].statuesque.id, 'tab:1')
        assert_equal(rendered[1].statuesque.role, 'tab')
        assert_equal(rendered[1].statuesque.on_click, 'unsupported')
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
            '%!v:lua.require\'statuesque\'.render_surface("status", "statusline")'
        )

        statuesque.install_surface('status', 'statusline')

        assert_equal(vim.o.laststatus, 3)
        assert_equal(vim.o.statusline, '%!v:lua.require\'statuesque\'.render_surface("status", "statusline")')

        vim.o.laststatus = 2
        statuesque.install_surface('status', 'statusline')
        assert_equal(vim.o.laststatus, 3)
    end)

    it('routes custom render targets through the backend registry', function()
        statuesque.register_backend('demo-backend', {
            render = function(render_spec)
                return 'demo:' .. statuesque.render(render_spec, 'text')
            end,
        })

        assert_equal(statuesque.render({ 'ok' }, 'demo-backend'), 'demo:ok')
    end)

    it('installs the default preset on demand without manifold wiring', function()
        statuesque.setup({
            manifold = false,
            preset = {
                status_sigil = 'S',
            },
        })

        assert_equal(vim.o.laststatus, 3)
        assert_equal(vim.o.statusline, '%!v:lua.require\'statuesque\'.render_surface("statusline", "statusline")')
        assert_equal(vim.o.tabline, '%!v:lua.require\'statuesque\'.render_surface("tabline", "tabline")')
        assert_equal(vim.o.winbar, '%!v:lua.require\'statuesque\'.render_surface("winbar", "winbar")')
        assert(statuesque.render_surface('statusline', 'text'):find('S', 1, true))
    end)

    it('uses Tabulature render specs in the default tabline when available', function()
        package.loaded['tabulature'] = nil
        package.loaded['tabulature.render.statuesque'] = nil
        local previous_tabulature = package.preload['tabulature']
        local previous_renderer = package.preload['tabulature.render.statuesque']
        package.preload['tabulature'] = function()
            return {
                api = {
                    tree = function()
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
                },
            }
        end
        package.preload['tabulature.render.statuesque'] = function()
            return {
                to_spec = function()
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
        package.loaded['tabulature.render.statuesque'] = nil
        package.preload['tabulature'] = previous_tabulature
        package.preload['tabulature.render.statuesque'] = previous_renderer

        assert(rendered:find('𝄞', 1, true), rendered)
        assert(rendered:find('Alpha', 1, true), rendered)
    end)

    it('renders default preset surfaces with distinct visual responsibilities', function()
        local surfaces = require('statuesque.presets.default').surfaces({
            tabulature = false,
            status_sigil = 'S',
            tabline_sigil = 'T',
            winbar_sigil = 'W',
        })

        local statusline = statuesque.render(surfaces.statusline, 'text', { mode = 'normal' })
        local tabline = statuesque.render(surfaces.tabline, 'text')
        local winbar = statuesque.render(surfaces.winbar, 'text')

        assert(statusline:find('S', 1, true), statusline)
        assert(statusline:find('NORMAL', 1, true), statusline)
        assert(statusline:find('[No Name]', 1, true), statusline)
        assert(statusline:find('utf-8 unix', 1, true), statusline)
        assert(tabline:find('T', 1, true), tabline)
        assert(tabline:find('statuesque.nvim', 1, true), tabline)
        assert(winbar:find('W', 1, true), winbar)
        assert(winbar:find('[No Name]', 1, true), winbar)
    end)

    it('fails explicitly for unsupported render and install targets', function()
        local render_ok, render_err = pcall(function()
            statuesque.render({ 'ready' }, 'floating-widget')
        end)
        local install_ok, install_err = pcall(function()
            statuesque.install_surface('status', 'floating-widget')
        end)

        assert(not render_ok)
        assert(tostring(render_err):find('unsupported statuesque render target: floating-widget', 1, true))
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
end)

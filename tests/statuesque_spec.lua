local statuesque = require('statuesque')

local function assert_equal(actual, expected)
    assert(actual == expected, ('expected %q, got %q'):format(tostring(expected), tostring(actual)))
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

    it('renders Vim target syntax with escaping, highlights, and clicks', function()
        local rendered = statuesque.render({
            {
                hl = 'StatuesqueActive',
                on_click = { id = 'domain.select', args = { domain = 1 } },
                '100% Alpha',
            },
        }, 'tabline')

        assert(rendered:find('%#StatuesqueActive#', 1, true), rendered)
        assert(rendered:find('100%%%% Alpha', 1, true), rendered)
        assert(rendered:find('@v:lua.__statuesque_click@', 1, true), rendered)
        assert(rendered:find('%T', 1, true), rendered)
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

    it('builds and installs statusline-family surface expressions', function()
        statuesque.set_surface('status', { 'ready' })

        assert_equal(
            statuesque.surface_expression('status', 'statusline'),
            '%!v:lua.require\'statuesque\'.render_surface("status", "statusline")'
        )

        statuesque.install_surface('status', 'statusline')

        assert_equal(vim.o.laststatus, 3)
        assert_equal(vim.o.statusline, '%!v:lua.require\'statuesque\'.render_surface("status", "statusline")')
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
end)

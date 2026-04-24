local manifold = require('statuesque.manifold')

local function assert_equal(actual, expected)
    assert(actual == expected, ('expected %q, got %q'):format(tostring(expected), tostring(actual)))
end

describe('statuesque manifold capability', function()
    it('exposes a versioned Manifold capability record', function()
        local capabilities = manifold.capabilities()

        assert_equal(capabilities.plugin, 'statuesque')
        assert_equal(capabilities.protocol_version, 1)
        assert_equal(capabilities.snapshot, true)
        assert(capabilities.features[1] == 'render_spec')
    end)

    it('exports configured status surfaces as plain render specs', function()
        local statuesque = require('statuesque')
        statuesque.register_provider('status', function(context)
            return {
                'mode:',
                context.mode,
                {
                    text = ' hidden',
                    on_click = function() end,
                },
            }
        end)
        statuesque.set_surface('statusline', 'status')

        local snapshot = manifold.status_snapshot('statusline', {
            mode = 'insert',
        })

        assert_equal(snapshot.kind, 'statuesque.status_snapshot')
        assert_equal(snapshot.surface, 'statusline')
        assert_equal(snapshot.spec[1], 'mode:')
        assert_equal(snapshot.spec[2], 'insert')
        assert_equal(snapshot.spec[3].text, ' hidden')
        assert_equal(snapshot.spec[3].on_click, nil)
    end)

    it('publishes status updates through injected Manifold attachments', function()
        local statuesque = require('statuesque')
        statuesque.set_surface('statusline', {
            {
                text = 'ready',
                role = 'status',
            },
        })

        local original_sockconnect = vim.fn.sockconnect
        local original_rpcnotify = vim.fn.rpcnotify
        local published = nil

        vim.g.manifold_child_control = {
            attachments = {
                ['manifold:child:1'] = {
                    host_server = '/tmp/manifold.sock',
                },
            },
        }
        vim.fn.sockconnect = function(kind, path, opts)
            assert_equal(kind, 'pipe')
            assert_equal(path, '/tmp/manifold.sock')
            assert_equal(opts.rpc, true)
            return 42
        end
        vim.fn.rpcnotify = function(channel, method, source, args)
            published = {
                channel = channel,
                method = method,
                source = source,
                args = args,
            }
            return true
        end

        local count = manifold.publish_status('statusline')

        assert_equal(count, 1)
        assert_equal(published.channel, 42)
        assert_equal(published.method, 'nvim_exec_lua')
        assert(published.source:find('_handle_child_suite_event', 1, true))
        assert_equal(published.args[1], 'manifold:child:1')
        assert_equal(published.args[2].kind, 'statuesque.status_update')
        assert_equal(published.args[2].spec[1].text, 'ready')
        assert_equal(vim.g.manifold_child_control.attachments['manifold:child:1'].channel, 42)

        vim.fn.sockconnect = original_sockconnect
        vim.fn.rpcnotify = original_rpcnotify
        vim.g.manifold_child_control = nil
    end)

    it('automatically publishes statusline surface changes when attached to Manifold', function()
        local statuesque = require('statuesque')
        local original_sockconnect = vim.fn.sockconnect
        local original_rpcnotify = vim.fn.rpcnotify
        local published = {}

        vim.g.manifold_child_control = {
            attachments = {
                ['manifold:child:1'] = {
                    host_server = '/tmp/manifold.sock',
                },
            },
        }
        vim.fn.sockconnect = function()
            return 42
        end
        vim.fn.rpcnotify = function(_, _, _, args)
            published[#published + 1] = args[2]
            return true
        end

        statuesque.set_surface('statusline', {
            {
                text = 'auto status',
                role = 'status',
            },
        })

        local did_publish = vim.wait(1000, function()
            return #published >= 1
        end, 10)

        vim.fn.sockconnect = original_sockconnect
        vim.fn.rpcnotify = original_rpcnotify
        vim.g.manifold_child_control = nil

        assert(did_publish)
        assert_equal(published[1].kind, 'statuesque.status_update')
        assert_equal(published[1].spec[1].text, 'auto status')
    end)

    it('coalesces rapid automatic statusline publishes to the final surface value', function()
        local statuesque = require('statuesque')
        local original_sockconnect = vim.fn.sockconnect
        local original_rpcnotify = vim.fn.rpcnotify
        local published = {}

        vim.g.manifold_child_control = {
            attachments = {
                ['manifold:child:1'] = {
                    host_server = '/tmp/manifold.sock',
                },
            },
        }
        vim.fn.sockconnect = function()
            return 42
        end
        vim.fn.rpcnotify = function(_, _, _, args)
            published[#published + 1] = args[2]
            return true
        end

        statuesque.set_surface('statusline', {
            {
                text = 'first',
            },
        })
        statuesque.set_surface('statusline', {
            {
                text = 'second',
            },
        })

        local did_publish = vim.wait(1000, function()
            return #published >= 1
        end, 10)

        vim.fn.sockconnect = original_sockconnect
        vim.fn.rpcnotify = original_rpcnotify
        vim.g.manifold_child_control = nil

        assert(did_publish)
        assert_equal(#published, 1)
        assert_equal(published[1].spec[1].text, 'second')
    end)

    it('auto-detects a Manifold host and installs the host status provider from normal setup', function()
        local statuesque = require('statuesque')
        local installed = false
        package.loaded['manifold'] = {
            is_host = function()
                return true
            end,
            install_statusline_provider = function(opts)
                installed = opts.surface == 'statusline' and opts.install == true
                return installed
            end,
        }

        statuesque.setup({})

        package.loaded['manifold'] = nil

        assert(installed)
    end)

    it('auto-detects a Manifold child attachment and exports nested editor status without local statusline', function()
        local statuesque = require('statuesque')
        local original_sockconnect = vim.fn.sockconnect
        local original_rpcnotify = vim.fn.rpcnotify
        local published = {}

        vim.g.manifold_child_control = {
            attachments = {
                ['manifold:child:1'] = {
                    host_server = '/tmp/manifold.sock',
                },
            },
        }
        vim.fn.sockconnect = function()
            return 42
        end
        vim.fn.rpcnotify = function(_, _, _, args)
            published[#published + 1] = args[2]
            return true
        end

        statuesque.setup({})

        local did_publish = vim.wait(1000, function()
            return #published >= 1
        end, 10)

        vim.fn.sockconnect = original_sockconnect
        vim.fn.rpcnotify = original_rpcnotify
        vim.g.manifold_child_control = nil

        assert(did_publish)
        assert_equal(published[1].kind, 'statuesque.status_update')
        assert_equal(published[1].spec[1].role, 'child-editor-status')
        assert_equal(published[1].spec[1].children[1].role, 'mode')
        assert_equal(vim.o.laststatus, 0)
    end)
end)

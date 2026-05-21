package.path = table.concat({
    './lua/?.lua',
    './lua/?/init.lua',
    package.path,
}, ';')

local test_filter = vim.env.STATUESQUE_TEST_FILTER

function _G.describe(name, body)
    io.write(name .. '\n')
    body()
end

function _G.it(name, body)
    if test_filter ~= nil and test_filter ~= '' and not name:find(test_filter, 1, true) then
        return
    end
    local ok, err = pcall(body)
    if ok then
        io.write('  ok - ' .. name .. '\n')
    else
        io.write('  not ok - ' .. name .. '\n')
        io.write(tostring(err) .. '\n')
        error(err, 0)
    end
end

dofile('tests/statuesque_spec.lua')
dofile('tests/manifold_capability_spec.lua')

io.write('statuesque tests passed\n')

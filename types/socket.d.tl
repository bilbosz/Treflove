-- The part of luasocket Treflove uses (LÖVE bundles luasocket; the test
-- runner stubs it under plain LuaJIT, tests/run.lua).
local record socket
    gettime: function(): number
end

return socket

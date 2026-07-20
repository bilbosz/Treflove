---Test suite entry point. Runs under plain LuaJIT (`luajit tests/run.lua` from
---the repository root) and inside LÖVE (`love . test`) — see test-code.sh.
-- Plain LuaJIT has no bundled luasocket; utils/utils.lua only needs
-- `socket.gettime`, so provide a stub before anything requires it.
local has_socket = pcall(require, "socket")
if not has_socket then
    package.preload["socket"] = function()
        return {
            gettime = function()
                return os.clock()
            end
        }
    end
end

require("app.globals")

local test = require("tests.lib.test")

local TEST_MODULES = {
    "tests.test-aabb",
    "tests.test-arg-parser",
    "tests.test-backstack-manager",
    "tests.test-class",
    "tests.test-connection",
    "tests.test-defer-manager",
    "tests.test-event-manager",
    "tests.test-table"
}

for _, module_name in ipairs(TEST_MODULES) do
    require(module_name)
end

local failed = test.report()
io.stdout:flush()
os.exit(failed == 0 and 0 or 1)

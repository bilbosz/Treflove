-- Test suite entry point. Runs under plain LuaJIT (`luajit tests/run.lua` from
-- the repository root) and inside LÖVE (`love . test`) — see test-code.sh.
-- Both need the build (`./build-code.sh`): the modules, the test modules and
-- tests/lib are Teal, required from build/.
package.path = "build/?.lua;build/?/init.lua;" .. package.path

-- Under the debugger of VS Code's "Local Lua Debugger" extension
-- (.vscode/launch.json): start it and load every module under its source's
-- name, so breakpoints in .tlt files stop there (.vscode/launch.lua). Under
-- LÖVE, conf.lua has done it already.
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" and not love then
    dofile(".vscode/launch.lua")
end

-- Plain LuaJIT has no bundled luasocket; utils/utils.tlt only needs
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

-- Plain LuaJIT has no `utf8` library either (LÖVE bundles one); the text
-- editing code only needs `len`, `offset` and `codes`.
local has_utf8 = pcall(require, "utf8")
if not has_utf8 then
    package.preload["utf8"] = function()
        return require("tests.lib.utf8-shim")
    end
end

require("app.globals")

local test = require("tests.lib.test")

local TEST_MODULES = {
    "tests.test-aabb",
    "tests.test-arg-parser",
    "tests.test-asset-manager",
    "tests.test-backstack-manager",
    "tests.test-button-event",
    "tests.test-class",
    "tests.test-connection",
    "tests.test-defer-manager",
    "tests.test-event",
    "tests.test-form-screen",
    "tests.test-keyboard",
    "tests.test-lifetime-class",
    "tests.test-pointer-event",
    "tests.test-session",
    "tests.test-table",
    "tests.test-text-event"
}

for _, module_name in ipairs(TEST_MODULES) do
    require(module_name)
end

local failed = test.report()
io.stdout:flush()
os.exit(failed == 0 and 0 or 1)

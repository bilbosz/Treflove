-- The project first: the submodule carries a tests/lib/test.lua of its own
package.path = "./?.lua;lib/lua-lifetime/?.lua;lib/lua-lifetime/?/init.lua;" .. package.path
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
    "tests.test-backstack-manager",
    "tests.test-button-event",
    "tests.test-class",
    "tests.test-connection",
    "tests.test-defer-manager",
    "tests.test-event",
    "tests.test-fonts",
    "tests.test-game-data-rp",
    "tests.test-image",
    "tests.test-images",
    "tests.test-input",
    "tests.test-keyboard",
    "tests.test-lifetimes",
    "tests.test-permissions",
    "tests.test-pointer-event",
    "tests.test-preview-area",
    "tests.test-screen-manager",
    "tests.test-session",
    "tests.test-table",
    "tests.test-text",
    "tests.test-text-event",
    "tests.test-tree",
    "tests.test-waiting-screen"
}

for _, module_name in ipairs(TEST_MODULES) do
    require(module_name)
end

local failed = test.report()
io.stdout:flush()
os.exit(failed == 0 and 0 or 1)

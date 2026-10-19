local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Control = require("controls.control")
local Screen = require("screens.screen")
local ScreenManager = require("screens.screen-manager")

-- lua-lifetime: the screen manager watches the shown screen with a hook. A
-- screen destroyed while shown hides itself and is forgotten; a replaced
-- screen that dies later is none of the manager's business.

---@return AppMock
---@return ScreenManager
local function setup()
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    app_mock.root = Control()
    return app_mock, ScreenManager()
end

test.suite("ScreenManager")

test.case("show hides the previous screen and shows the next", function()
    local app_mock, manager = setup()
    local first, second = Screen(), Screen()
    manager:show(first)
    test.assert_eq(first:get_control():get_parent(), app_mock.root)
    manager:show(second)
    test.assert_eq(first:get_control():get_parent(), nil)
    test.assert_eq(second:get_control():get_parent(), app_mock.root)
    test.assert_eq(manager:get_screen(), second)
end)

test.case("a shown screen that is destroyed hides itself and is forgotten", function()
    local app_mock, manager = setup()
    local owner = {}
    local screen = Screen():attach_lifetime(owner)
    manager:show(screen)
    test.assert_deep_eq(app_mock.root:get_children(), {
        screen:get_control()
    })

    lifetime.destroy(owner)
    test.assert_false(lifetime.alive(screen))
    test.assert_deep_eq(app_mock.root:get_children(), {}, "the screen's control left the root")
    test.assert_eq(manager:get_screen(), nil)

    local next_screen = Screen()
    manager:show(next_screen)
    test.assert_eq(manager:get_screen(), next_screen, "nothing dead to hide first")
end)

test.case("a replaced screen that dies later leaves the current screen alone", function()
    local _, manager = setup()
    local first, second = Screen(), Screen()
    manager:show(first)
    manager:show(second)
    lifetime.destroy(first)
    test.assert_eq(manager:get_screen(), second)
    test.assert_eq(#lifetime.dependents(second), 1, "one hook, on the current screen only")
    test.assert_deep_eq(lifetime.dependents(first), {}, "the first screen's hook was discarded with the switch")
end)

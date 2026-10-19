local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Control = require("controls.control")
local WaitingScreen = require("screens.waiting-screen")

-- A transient screen: no lifetime, registrations that follow show/hide.

test.suite("WaitingScreen")

test.case("the logo spins only while the screen is shown", function()
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    app_mock.root = Control()
    app_mock.width, app_mock.height = 2000, 1500

    local screen = WaitingScreen("Loading...")
    test.assert_eq(app_mock.update_event:get_handler(screen), nil, "not registered until shown")

    screen:show()
    test.assert_eq(app_mock.update_event:get_handler(screen), WaitingScreen.on_update)
    test.assert_eq(screen:get_control():get_parent(), app_mock.root)
    app_mock.update_event:trigger(0.5)

    screen:hide()
    test.assert_eq(app_mock.update_event:get_handler(screen), nil, "unregistered with hide")
    test.assert_eq(screen:get_control():get_parent(), nil)
end)

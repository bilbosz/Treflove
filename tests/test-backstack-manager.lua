local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Consts = require("app.consts")
local BackstackManager = require("utils.backstack-manager")

test.suite("BackstackManager")

test.case("registers itself with the keyboard manager", function()
    local registered
    mocks.install_app({
        keyboard_manager = {
            register_listener = function(_, listener)
                registered = listener
            end
        }
    })
    local manager = BackstackManager()
    test.assert_eq(registered, manager)
end)

test.case("back invokes and pops callbacks in LIFO order", function()
    mocks.install_app()
    local manager = BackstackManager()
    local calls = {}
    manager:push(function()
        table.insert(calls, "first")
    end)
    manager:push(function()
        table.insert(calls, "second")
    end)

    manager:back()
    manager:back()
    manager:back()

    test.assert_deep_eq(calls, {
        "second",
        "first"
    })
    test.assert_eq(manager:get_top(), nil)
end)

test.case("pop removes only the top callback and only when it matches", function()
    mocks.install_app()
    local manager = BackstackManager()
    local bottom = function()
    end
    local top = function()
    end
    manager:push(bottom)
    manager:push(top)

    manager:pop(bottom)
    test.assert_eq(manager:get_top(), top, "popping a non-top callback is a no-op")

    manager:pop(top)
    test.assert_eq(manager:get_top(), bottom)
end)

test.case("push accepts only functions", function()
    mocks.install_app()
    local manager = BackstackManager()
    test.assert_error(function()
        manager:push("not a function")
    end)
end)

test.case("the backstack key triggers back", function()
    mocks.install_app()
    local manager = BackstackManager()
    local calls = 0
    manager:push(function()
        calls = calls + 1
    end)

    manager:on_key_pressed("a")
    test.assert_eq(calls, 0, "other keys are ignored")

    manager:on_key_pressed(Consts.BACKSTACK_KEY)
    test.assert_eq(calls, 1)
end)

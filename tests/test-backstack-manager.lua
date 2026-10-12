local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Consts = require("app.consts")
local BackstackManager = require("utils.backstack-manager")
local lifetime = require("lifetime")

test.suite("BackstackManager")

test.case("registers itself on the key pressed event", function()
    local app_mock = mocks.install_app()
    local manager = BackstackManager()
    test.assert_eq(app_mock.keyboard_manager.key_pressed:get_handler(manager), BackstackManager.on_key_pressed)
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

test.case("push returns the entry, which get_top returns while it is on top", function()
    mocks.install_app()
    local manager = BackstackManager()
    local cb = function()
    end
    local entry = manager:push(cb)
    test.assert_eq(entry.cb, cb)
    test.assert_eq(manager:get_top(), entry)
end)

test.case("back destroys the top entry before running its callback", function()
    mocks.install_app()
    local manager = BackstackManager()
    local bottom = manager:push(function()
    end)
    local seen = {}
    local top
    top = manager:push(function()
        table.insert(seen, lifetime.alive(top))
        table.insert(seen, manager:get_top() == bottom)
    end)

    manager:back()
    test.assert_deep_eq(seen, {
        false,
        true
    }, "inside the callback the entry is dead and off the stack")
    test.assert_false(lifetime.alive(top))
    test.assert_true(lifetime.alive(bottom))
end)

test.case("destroying an entry removes it from the stack wherever it is", function()
    mocks.install_app()
    local manager = BackstackManager()
    local bottom = manager:push(function()
    end)
    local middle = manager:push(function()
    end)
    local top = manager:push(function()
    end)

    lifetime.destroy(middle)
    test.assert_eq(#manager._stack, 2)
    test.assert_eq(manager._stack[1], bottom)
    test.assert_eq(manager._stack[2], top)
end)

test.case("destroying an anchored entry's owner removes the entry from the stack", function()
    mocks.install_app()
    local manager = BackstackManager()
    local calls = 0
    local bottom = manager:push(function()
        calls = calls + 1
    end)
    local period = lifetime.token("period")
    -- `manager:push(cb) @ period`
    local entry = lifetime.attach(manager:push(function()
        calls = calls + 10
    end), false, period)
    test.assert_eq(manager:get_top(), entry)

    lifetime.destroy(period)
    test.assert_false(lifetime.alive(entry), "the entry died with its owner")
    test.assert_eq(manager:get_top(), bottom, "and left the stack")
    test.assert_eq(calls, 0, "without running its callback")

    manager:back()
    test.assert_eq(calls, 1)
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

test.case("the backstack key dispatched by the keyboard manager triggers back", function()
    local app_mock = mocks.install_app()
    local manager = BackstackManager()
    local calls = 0
    local function _count()
        calls = calls + 1
    end
    manager:push(_count)
    manager:push(_count)

    app_mock.keyboard_manager:dispatch_key_pressed("a")
    test.assert_eq(calls, 0, "other keys are ignored")

    app_mock.keyboard_manager:dispatch_key_pressed(Consts.BACKSTACK_KEY)
    test.assert_eq(calls, 1)
end)

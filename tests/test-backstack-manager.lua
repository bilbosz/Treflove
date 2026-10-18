local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Consts = require("app.consts")
local BackstackManager = require("utils.backstack-manager")

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

test.case("push returns the entry; back destroys it before running its callback", function()
    mocks.install_app()
    local manager = BackstackManager()
    local bottom = manager:push(function()
    end)
    local depth_in_cb
    local top = manager:push(function()
        depth_in_cb = manager:get_top()
    end)
    test.assert_eq(manager:get_top(), top)

    manager:back()
    test.assert_eq(depth_in_cb, bottom, "the callback already sees the entry gone")
    test.assert_false(lifetime.alive(top))
    test.assert_eq(manager:get_top(), bottom)
end)

test.case("an entry anchored to an owner leaves the stack when the owner dies, wherever it sits", function()
    mocks.install_app()
    local manager = BackstackManager()
    local owner = {}
    local root = manager:push(function()
    end)
    local owned = lifetime.attach(manager:push(function()
    end), owner)
    local above = manager:push(function()
    end)
    test.assert_eq(manager:get_top(), above)

    lifetime.destroy(owner)
    test.assert_false(lifetime.alive(owned))
    test.assert_eq(manager:get_top(), above, "the entry above is untouched")
    manager:back()
    test.assert_eq(manager:get_top(), root, "the owned entry is gone from the middle")
end)

test.case("destroying an entry by hand pops it without running its callback", function()
    mocks.install_app()
    local manager = BackstackManager()
    local calls = 0
    local entry = manager:push(function()
        calls = calls + 1
    end)
    lifetime.destroy(entry)
    test.assert_eq(calls, 0)
    test.assert_eq(manager:get_top(), nil)
    manager:back()
    test.assert_eq(calls, 0, "nothing left to run")
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

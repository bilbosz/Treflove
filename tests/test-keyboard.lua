local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local KeyboardManager = require("events.keyboard")

---@class TestKeyOwner: Object
---@field keys love.KeyConstant[]
local TestKeyOwner = class("TestKeyOwner")

function TestKeyOwner:init()
    self.keys = {}
end

---@param key love.KeyConstant
function TestKeyOwner:on_key(key)
    table.insert(self.keys, key)
end

test.suite("KeyboardManager")

test.case("presses go to the pressed event only", function()
    local manager = KeyboardManager()
    local pressed, released = TestKeyOwner(), TestKeyOwner()
    manager.key_pressed:register(pressed, pressed.on_key)
    manager.key_released:register(released, released.on_key)

    manager:dispatch_key_pressed("a")

    test.assert_deep_eq(pressed.keys, {
        "a"
    })
    test.assert_deep_eq(released.keys, {})
end)

test.case("releases go to the released event only", function()
    local manager = KeyboardManager()
    local pressed, released = TestKeyOwner(), TestKeyOwner()
    manager.key_pressed:register(pressed, pressed.on_key)
    manager.key_released:register(released, released.on_key)

    manager:dispatch_key_released("b")

    test.assert_deep_eq(pressed.keys, {})
    test.assert_deep_eq(released.keys, {
        "b"
    })
end)

test.case("a dispatched key is down until it is released through dispatch", function()
    local manager = KeyboardManager(mocks.make_keyboard(), mocks.make_system())

    test.assert_false(manager:is_key_down("lshift"))
    manager:dispatch_key_pressed("lshift")
    test.assert_true(manager:is_key_down("lshift"))
    test.assert_false(manager:is_key_down("rshift"))
    manager:dispatch_key_released("lshift")
    test.assert_false(manager:is_key_down("lshift"))
end)

test.case("the key is down when the owners of the pressed event hear of it, up when the owners of the released event do", function()
    local manager = KeyboardManager(mocks.make_keyboard(), mocks.make_system())
    ---@type boolean[]
    local seen = {}
    local owner = TestKeyOwner()
    manager.key_pressed:register(owner, function()
        table.insert(seen, manager:is_key_down("a"))
    end)
    manager.key_released:register(owner, function()
        table.insert(seen, manager:is_key_down("a"))
    end)

    manager:dispatch_key_pressed("a")
    manager:dispatch_key_released("a")

    test.assert_deep_eq(seen, {
        true,
        false
    })
end)

test.case("a key the backend reports down is down without a dispatch", function()
    local keyboard = mocks.make_keyboard()
    local manager = KeyboardManager(keyboard, mocks.make_system())

    keyboard.down["rctrl"] = true

    test.assert_true(manager:is_key_down("rctrl"))
    test.assert_true(manager:is_ctrl_down())
end)

test.case("either control key is ctrl, either shift key is shift", function()
    local manager = KeyboardManager(mocks.make_keyboard(), mocks.make_system())

    for _, key in ipairs({
        "lctrl",
        "rctrl"
    }) do
        manager:dispatch_key_pressed(key)
        test.assert_true(manager:is_ctrl_down(), key)
        test.assert_false(manager:is_shift_down(), key)
        manager:dispatch_key_released(key)
        test.assert_false(manager:is_ctrl_down(), key)
    end
    for _, key in ipairs({
        "lshift",
        "rshift"
    }) do
        manager:dispatch_key_pressed(key)
        test.assert_true(manager:is_shift_down(), key)
        test.assert_false(manager:is_ctrl_down(), key)
        manager:dispatch_key_released(key)
        test.assert_false(manager:is_shift_down(), key)
    end
end)

test.case("the command keys are ctrl on macOS only", function()
    local system = mocks.make_system()
    local manager = KeyboardManager(mocks.make_keyboard(), system)

    manager:dispatch_key_pressed(KeyboardManager.LEFT_COMMAND_KEY)
    test.assert_false(manager:is_ctrl_down(), "lgui on Linux")
    system.os = "OS X"
    test.assert_true(manager:is_ctrl_down(), "lgui on macOS")
    manager:dispatch_key_released(KeyboardManager.LEFT_COMMAND_KEY)
    manager:dispatch_key_pressed(KeyboardManager.RIGHT_COMMAND_KEY)
    test.assert_true(manager:is_ctrl_down(), "rgui on macOS")
    manager:dispatch_key_released(KeyboardManager.RIGHT_COMMAND_KEY)
    test.assert_false(manager:is_ctrl_down())
end)

test.case("release_all forgets every tracked key and triggers nothing", function()
    local keyboard = mocks.make_keyboard()
    local manager = KeyboardManager(keyboard, mocks.make_system())
    local released = TestKeyOwner()
    manager.key_released:register(released, released.on_key)
    manager:dispatch_key_pressed("lctrl")
    manager:dispatch_key_pressed("lshift")
    keyboard.down["rshift"] = true

    manager:release_all()

    test.assert_false(manager:is_ctrl_down())
    test.assert_false(manager:is_key_down("lshift"))
    test.assert_true(manager:is_shift_down(), "the backend still reports rshift")
    test.assert_deep_eq(released.keys, {})
end)

test.case("without a backend, love.keyboard is read at the call", function()
    local previous = love.keyboard
    local keyboard = mocks.make_keyboard()
    local manager = KeyboardManager()
    love.keyboard = keyboard

    keyboard.down["lshift"] = true
    local shift = manager:is_shift_down()
    love.keyboard = previous

    test.assert_true(shift)
end)

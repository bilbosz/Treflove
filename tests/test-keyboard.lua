local test = require("tests.lib.test")
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

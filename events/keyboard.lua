local Event = require("events.event")

---Dispatches key presses and releases as the `key_pressed` / `key_released`
---events. Both are always delivered, also while text input is active, so
---navigation keeps working while typing (backstack, form focus, button
---activation); text editing keys are routed separately by `TextEventManager`.
---
---Handlers receive `(owner, key)`; e.g.
---`app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)`.
---@class KeyboardManager: Object
---@field public key_pressed Event Triggered with (key)
---@field public key_released Event Triggered with (key)
local KeyboardManager = class("KeyboardManager")

function KeyboardManager:init()
    self.key_pressed = Event()
    self.key_released = Event()
end

---@param key love.KeyConstant
function KeyboardManager:dispatch_key_pressed(key)
    self.key_pressed:trigger(key)
end

---@param key love.KeyConstant
function KeyboardManager:dispatch_key_released(key)
    self.key_released:trigger(key)
end

---@param key love.KeyConstant
---@return boolean
function KeyboardManager:is_key_down(key)
    return love.keyboard.isDown(key)
end

return KeyboardManager

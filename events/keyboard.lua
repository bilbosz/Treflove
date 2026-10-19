local Event = require("events.event")

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

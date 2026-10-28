local Event = require("events.event")

---@class KeyboardManager: Object
---@field public key_pressed Event Triggered with (key)
---@field public key_released Event Triggered with (key)
---@field private _keyboard love.keyboard|nil The backend given; `love.keyboard` when nil
---@field private _system love.system|nil The backend given; `love.system` when nil
---@field private _down table<love.KeyConstant, boolean> The keys pressed and not yet released through dispatch
local KeyboardManager = class("KeyboardManager")

-- LÖVE 11 names macOS's command keys so (it rejects "lsuper" and "lmeta"); the annotation package lists them as scancodes only
KeyboardManager.LEFT_COMMAND_KEY = ("lgui") --[[@as love.KeyConstant]]
KeyboardManager.RIGHT_COMMAND_KEY = ("rgui") --[[@as love.KeyConstant]]

---@param keyboard love.keyboard|nil The backend `is_key_down` falls back to; `love.keyboard` by default, read at the call
---@param system love.system|nil The backend that names the operating system; `love.system` by default, read at the call
function KeyboardManager:init(keyboard, system)
    self.key_pressed = Event()
    self.key_released = Event()
    self._keyboard = keyboard
    self._system = system
    self._down = {}
end

---@param key love.KeyConstant
function KeyboardManager:dispatch_key_pressed(key)
    self._down[key] = true
    self.key_pressed:trigger(key)
end

---@param key love.KeyConstant
function KeyboardManager:dispatch_key_released(key)
    self._down[key] = nil
    self.key_released:trigger(key)
end

---@param key love.KeyConstant
---@return boolean True when the key was pressed and not yet released through dispatch, or the backend reports it down
function KeyboardManager:is_key_down(key)
    return self._down[key] == true or (self._keyboard or love.keyboard).isDown(key)
end

---@return boolean lctrl or rctrl; on macOS lgui or rgui too
function KeyboardManager:is_ctrl_down()
    if self:is_key_down("lctrl") or self:is_key_down("rctrl") then
        return true
    end
    return (self._system or love.system).getOS() == "OS X" and (self:is_key_down(KeyboardManager.LEFT_COMMAND_KEY) or self:is_key_down(KeyboardManager.RIGHT_COMMAND_KEY))
end

---@return boolean lshift or rshift
function KeyboardManager:is_shift_down()
    return self:is_key_down("lshift") or self:is_key_down("rshift")
end

function KeyboardManager:release_all()
    self._down = {}
end

return KeyboardManager

local EventManager = require("events.event-manager")

---@class WheelEventListener
local WheelEventListener = class("WheelEventListener")

function WheelEventListener:on_wheel_moved(x, y)
    abstract()
end

---@class WheelEventManager: EventManager
local WheelEventManager = class("WheelEventManager", EventManager)

function WheelEventManager:init()
    EventManager.init(self, WheelEventListener)
end

return {
    Listener = WheelEventListener,
    Manager = WheelEventManager
}

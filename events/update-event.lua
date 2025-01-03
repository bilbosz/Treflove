local EventManager = require("events.event-manager")

---@class UpdateEventListener
local UpdateEventListener = class("UpdateEventListener")

---@param dt number
function UpdateEventListener:on_update(dt)
    abstract()
end

---@class UpdateEventManager: EventManager
local UpdateEventManager = class("UpdateEventManager", EventManager)

function UpdateEventManager:init()
    EventManager.init(self, UpdateEventListener)
end

return {
    Listener = UpdateEventListener,
    Manager = UpdateEventManager
}

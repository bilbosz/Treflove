local EventManager = require("events.event-manager")

---@class KeyboardEventListener
local KeyboardEventListener = class("KeyboardEventListener")

function KeyboardEventListener:init(ignoreTextEvents)
    self.ignoreTextEvents = ignoreTextEvents
end

function KeyboardEventListener:on_key_pressed(key)

end

function KeyboardEventListener:on_key_released(key)

end

function KeyboardEventListener:ignore_text_events()
    return self.ignoreTextEvents
end

---@class KeyboardManager: EventManager
local KeyboardManager = class("KeyboardManager", EventManager)

function KeyboardManager:init()
    EventManager.init(self, KeyboardEventListener)
end

function KeyboardManager:key_pressed(key)
    self:invoke_event(KeyboardEventListener.on_key_pressed, key)
end

function KeyboardManager:key_released(key)
    self:invoke_event(KeyboardEventListener.on_key_released, key)
end

function KeyboardManager:invoke_event(method, ...)
    assert(not self._lock)
    self._lock = true
    for listener, listenerMethod in pairs(self._methods[method]) do
        if not self._to_remove[listener] and (listener:ignore_text_events() or not app.text_event_manager:is_text_input()) then
            listenerMethod(listener, ...)
        end
    end
    self._lock = false
    self:handle_postponed()
end

function KeyboardManager:is_key_down(key)
    return love.keyboard.isDown(key)
end

return {
    Listener = KeyboardEventListener,
    Manager = KeyboardManager
}

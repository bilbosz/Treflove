KeyboardEventListener = {}

function KeyboardEventListener:Init(ignoreTextEvents)
    self.ignoreTextEvents = ignoreTextEvents
end

function KeyboardEventListener:OnKeyPressed(key)

end

function KeyboardEventListener:OnKeyReleased(key)

end

function KeyboardEventListener:IgnoreTextEvents()
    return self.ignoreTextEvents
end

MakeClassOf(KeyboardEventListener)

KeyboardManager = {}

function KeyboardManager:Init()
    EventManager.Init(self, KeyboardEventListener)
end

function KeyboardManager:KeyPressed(key)
    self:InvokeEvent(KeyboardEventListener.OnKeyPressed, key)
end

function KeyboardManager:KeyReleased(key)
    self:InvokeEvent(KeyboardEventListener.OnKeyReleased, key)
end

function KeyboardManager:InvokeEvent(method, ...)
    assert(not self.lock)
    self.lock = true
    for listener, listenerMethod in pairs(self.methods[method]) do
        if not self.toRemove[listener] and (listener:IgnoreTextEvents() or not app.textEventManager:IsTextInput()) then
            listenerMethod(listener, ...)
        end
    end
    self.lock = false
    self:HandlePostponed()
end

function KeyboardManager:IsKeyDown(key)
    return love.keyboard.isDown(key)
end

MakeClassOf(KeyboardManager, EventManager)

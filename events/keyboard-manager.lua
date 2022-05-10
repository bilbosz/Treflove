KeyboardEventListener = {}

function KeyboardEventListener:OnKeyPressed(key)

end

function KeyboardEventListener:OnKeyReleased(key)

end

MakeClassOf(KeyboardEventListener)

KeyboardManager = {}

function KeyboardManager:Init()
    EventManager.Init(self, KeyboardEventListener)
end

function KeyboardManager:KeyPressed(key)
    if app.textEventManager:IsTextInput() and key ~= Consts.BACKSTACK_KEY then
        return
    end
    self:InvokeEvent(KeyboardEventListener.OnKeyPressed, key)
end

function KeyboardManager:KeyReleased(key)
    if app.textEventManager:IsTextInput() and key ~= Consts.BACKSTACK_KEY then
        return
    end
    self:InvokeEvent(KeyboardEventListener.OnKeyReleased, key)
end

MakeClassOf(KeyboardManager, EventManager)

TextEventManager = {}

function TextEventManager:Init()
    EventManager.Init(self, TextEventListener)
end

function TextEventManager:KeyPressed(key)
    if key == "backspace" then
        self:InvokeEvent(TextEventListener.OnRemoveCharacter)
    end
end

function TextEventManager:TextInput(text)
    self:InvokeEvent(TextEventListener.OnAppendText, text)
end

MakeClassOf(TextEventManager, EventManager)

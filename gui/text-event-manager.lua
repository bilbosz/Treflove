TextEventManager = {}

function TextEventManager:Init()
    EventManager.Init(self, TextEventListener)
    love.keyboard.setKeyRepeat(love.keyboard.hasKeyRepeat())
    love.keyboard.setTextInput(false)
end

function TextEventManager:KeyPressed(key)
    if key == "backspace" then
        self:InvokeEvent(TextEventListener.OnRemoveCharacter)
    end
end

function TextEventManager:TextInput(text)
    self:InvokeEvent(TextEventListener.OnAppendText, text)
end

function TextEventManager:SetTextInput(value)
    love.keyboard.setTextInput(value)
end

MakeClassOf(TextEventManager, EventManager)

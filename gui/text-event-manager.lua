TextEventListener = {}

local utf8 = require("utf8")

function TextEventListener:Init()
    self.text = ""
end

function TextEventListener:OnRemoveText(characterNumber)
    local offset = utf8.offset(self.text, -characterNumber)
    if offset then
        self.text = string.sub(self.text, 1, offset - 1)
    end
end

function TextEventListener:OnAppendText(text)
    self.text = self.text .. text
end

function TextEventListener:OnEnter()
end

function TextEventListener:GetText()
    return self.text
end

function TextEventListener:SetText(text)
    self.text = text
end

function TextEventListener:GetTextLength()
    return utf8.len(self.text)
end

MakeClassOf(TextEventListener)

TextEventManager = {}

function TextEventManager:Init()
    EventManager.Init(self, TextEventListener)
    love.keyboard.setKeyRepeat(false)
    love.keyboard.setTextInput(false)
end

function TextEventManager:KeyPressed(key)
    if key == "backspace" then
        self:InvokeEvent(TextEventListener.OnRemoveText, 1)
    elseif key == "return" then
        self:InvokeEvent(TextEventListener.OnEnter)
    end
end

function TextEventManager:TextInput(text)
    self:InvokeEvent(TextEventListener.OnAppendText, text)
end

function TextEventManager:SetTextInput(value)
    love.keyboard.setTextInput(value)
    love.keyboard.setKeyRepeat(value)
end

MakeClassOf(TextEventManager, EventManager)

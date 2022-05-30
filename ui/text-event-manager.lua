TextEventListener = {}

local utf8 = require("utf8")

function TextEventListener:Init()
    self.text = ""
end

function TextEventListener:OnEdit(text)

end

function TextEventListener:OnEnter()

end

function TextEventListener:RemoveText(characterNumber)
    local offset = utf8.offset(self.text, -characterNumber)
    if offset then
        self.text = string.sub(self.text, 1, offset - 1)
        self:OnEdit(self.text)
    end
end

function TextEventListener:AppendText(text)
    self.text = self.text .. text
    self:OnEdit(self.text)
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
    self:SetTextInput(false)
    love.keyboard.setKeyRepeat(true)
end

function TextEventManager:TextInput(text)
    self:InvokeEvent(TextEventListener.AppendText, text)
end

function TextEventManager:KeyPressed(key)
    if not self:IsTextInput() then
        return
    end
    if key == "backspace" then
        self:InvokeEvent(TextEventListener.RemoveText, 1)
    elseif key == "return" then
        self:InvokeEvent(TextEventListener.OnEnter)
    end
end

function TextEventManager:SetTextInput(value)
    love.keyboard.setTextInput(value)
end

function TextEventManager:IsTextInput()
    return love.keyboard.hasTextInput()
end

MakeClassOf(TextEventManager, EventManager)

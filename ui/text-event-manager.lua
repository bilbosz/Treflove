TextEventListener = {}

local utf8 = require("utf8")

local WHITESPACE_CODES = {
    0x9,
    0xA,
    0xB,
    0xC,
    0xD,
    0x20,
    0x85,
    0xA0,
    0x1680,
    0x2000,
    0x2001
}

function TextEventListener:Init()
    self.text = ""
end

function TextEventListener:OnEdit(text)

end

function TextEventListener:OnEnter()

end

function TextEventListener:OnRemoveEmpty()

end

function TextEventListener:RemoveCharacters(characterNumber)
    local offset = utf8.offset(self.text, -characterNumber)
    if self.text == "" and characterNumber > 0 then
        self:OnRemoveEmpty()
    elseif offset then
        self.text = string.sub(self.text, 1, offset - 1)
        self:OnEdit(self.text)
    end
end

function TextEventListener:RemoveWord()
    if self.text == "" then
        self:OnRemoveEmpty()
    else
        local lastSpace = nil
        for i, code in utf8.codes(self.text) do
            for _, wcode in ipairs(WHITESPACE_CODES) do
                if code == wcode then
                    lastSpace = i
                end
            end
        end
        if lastSpace then
            self.text = string.sub(self.text, 1, lastSpace - 1)
        else
            self.text = ""
        end
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
        if love.keyboard.isDown("lctrl", "rctrl") then
            self:InvokeEvent(TextEventListener.RemoveWord)
        else
            self:InvokeEvent(TextEventListener.RemoveCharacters, 1)
        end
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

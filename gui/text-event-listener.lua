TextEventListener = {}

local utf8 = require("utf8")

function TextEventListener:Init()
    self.text = ""
end

function TextEventListener:OnRemoveCharacter()
    local offset = utf8.offset(self.text, -1)
    if offset then
        self.text = string.sub(self.text, 1, offset - 1)
    end
end

function TextEventListener:OnAppendText(text)
    self.text = self.text .. text
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

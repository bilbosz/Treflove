NumberInput = {}

function NumberInput:Init(parent, screen, width, height, onInput, onEnter)
    TextInput.Init(self, parent, screen, width, height, false, onInput, onEnter)
    self.number = 0
end

function NumberInput:SetNumber(number)
    self.number = number
    self:SetText(tostring(number))
end

function NumberInput:GetNumber()
    return self.number
end

function NumberInput:OnAppendText(text)
    if self.text == "" and text == "-" then
        self.number = 0
        TextEventListener.OnAppendText(self, text)
        return
    end
    local n = tonumber(self.text .. text)
    if n then
        self.number = n
        TextEventListener.OnAppendText(self, text)
    end
end

function TextInput:SetText(text)
    local n = tonumber(text)
    self.number = n
    TextInput.SetText(self, text)
end

MakeClassOf(NumberInput, TextInput)

local TextEventListener = require("ui.text-event").Listener
local TextInput = require("ui.text-input")

---@class NumberInput: TextInput
local NumberInput = class("NumberInput", TextInput)

function NumberInput:init(parent, formScreen, width, height, onInput, onEnter)
    TextInput.init(self, parent, formScreen, width, height, false, onInput, onEnter)
    self.number = 0
end

function NumberInput:set_number(number)
    self.number = number
    self:set_text(tostring(number))
end

function NumberInput:get_number()
    return self.number
end

function NumberInput:on_append_text(text)
    if self.text == "" and text == "-" then
        self.number = 0
        TextEventListener.on_append_text(self, text)
        return
    end
    local n = tonumber(self.text .. text)
    if n then
        self.number = n
        TextEventListener.on_append_text(self, text)
    end
end

function NumberInput:set_text(text)
    local n = tonumber(text)
    self.number = n
    TextInput.set_text(self, text)
end

return NumberInput

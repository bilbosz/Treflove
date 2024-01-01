local TextEventListener = require("ui.text-event").Listener
local TextInput = require("ui.text-input")

---@class NumberInput: TextInput
---@field private _number number
local NumberInput = class("NumberInput", TextInput)

---@param parent Control
---@param form_screen FormScreen
---@param width number
---@param height number
---@param on_input fun():void
---@param on_enter fun():void
---@return void
function NumberInput:init(parent, form_screen, width, height, on_input, on_enter)
    TextInput.init(self, parent, form_screen, width, height, false, on_input, on_enter)
    self._number = 0
end

---@param number number
---@return void
function NumberInput:set_number(number)
    self._number = number
    self:set_text(tostring(number))
end

---@return number
function NumberInput:get_number()
    return self._number
end

---@param text string
---@return void
function NumberInput:on_append_text(text)
    if TextEventListener.get_text(self) == "" and text == "-" then
        self._number = 0
        TextEventListener.on_append_text(self, text)
        return
    end
    local n = tonumber(TextEventListener.get_text(self) .. text)
    if n then
        self._number = n
        TextEventListener.on_append_text(self, text)
    end
end

---@param character_number number
---@return void
function NumberInput:on_remove_characters(character_number)
    TextEventListener.on_remove_characters(self, character_number)
    self._number = tonumber(TextEventListener.get_text(self))
end

---@param text string
---@return void
function NumberInput:set_text(text)
    local n = tonumber(text)
    self._number = n
    TextInput.set_text(self, text)
end

return NumberInput

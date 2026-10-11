local TextInput = require("ui.text-input")

---@class NumberInput: TextInput
---@field private _number number|nil Nil when the text is not a valid number
local NumberInput = class("NumberInput", TextInput)

---@param parent Control
---@param form_screen FormScreen
---@param width number
---@param height number
---@param on_input fun()|nil
---@param on_enter fun()|nil
function NumberInput:init(parent, form_screen, width, height, on_input, on_enter)
    TextInput.init(self, parent, form_screen, width, height, false, on_input, on_enter)
    self._number = 0
end

---@param number number
function NumberInput:set_number(number)
    self._number = number
    self:set_text(tostring(number))
end

---@return number|nil
function NumberInput:get_number()
    return self._number
end

---@param text string
function NumberInput:on_append_text(text)
    if self:get_text() == "" and text == "-" then
        self._number = 0
        TextInput.on_append_text(self, text)
        return
    end
    local n = tonumber(self:get_text() .. text)
    if n then
        self._number = n
        TextInput.on_append_text(self, text)
    end
end

---@param character_number number
function NumberInput:on_remove_characters(character_number)
    TextInput.on_remove_characters(self, character_number)
    self._number = tonumber(self:get_text())
end

---@param text string
function NumberInput:set_text(text)
    local n = tonumber(text)
    self._number = n
    TextInput.set_text(self, text)
end

return NumberInput

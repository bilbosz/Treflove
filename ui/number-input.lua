local TextInput = require("ui.text-input")

---@class NumberInput: TextInput
---@field private _number number|nil Nil when the text is not a valid number
local NumberInput = class("NumberInput", TextInput)

---@param candidate string
---@return boolean
local function _is_number_text(candidate)
    return candidate == "" or candidate == "-" or tonumber(candidate) ~= nil
end

---@param parent Control
---@param form_screen FormScreen
---@param width number
---@param height number
---@param on_input InputHandler|nil Run after an edit
---@param on_enter InputHandler|nil Run on the return key
function NumberInput:init(parent, form_screen, width, height, on_input, on_enter)
    TextInput.init(self, parent, form_screen, width, height, false, on_input, on_enter)
    self._number = 0
    self:set_filter(_is_number_text)
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
function NumberInput:on_edit(text)
    self._number = tonumber(text)
    TextInput.on_edit(self, text)
end

---@param text string
function NumberInput:set_text(text)
    local n = tonumber(text)
    self._number = n
    TextInput.set_text(self, text)
end

return NumberInput

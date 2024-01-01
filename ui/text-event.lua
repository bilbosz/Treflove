local EventManager = require("events.event-manager")
local utf8 = require("utf8")

---@class TextEventListener
---@field private _text string
local TextEventListener = class("TextEventListener")

---@type number[]
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

---@return void
function TextEventListener:init()
    self._text = ""
end

---@param text string
---@return void
function TextEventListener:on_edit(text)

end

---@return void
function TextEventListener:on_enter()

end

---@return void
function TextEventListener:on_remove_empty()

end

---@param character_number number
---@return void
function TextEventListener:on_remove_characters(character_number)
    local offset = utf8.offset(self._text, -character_number)
    if self._text == "" and character_number > 0 then
        self:on_remove_empty()
    elseif offset then
        self._text = string.sub(self._text, 1, offset - 1)
        self:on_edit(self._text)
    end
end

---@return void
function TextEventListener:on_remove_word()
    if self._text == "" then
        self:on_remove_empty()
    else
        local last_space = nil
        for i, code in utf8.codes(self._text) do
            for _, wcode in ipairs(WHITESPACE_CODES) do
                if code == wcode then
                    last_space = i
                end
            end
        end
        if last_space then
            self._text = string.sub(self._text, 1, last_space - 1)
        else
            self._text = ""
        end
        self:on_edit(self._text)
    end
end

---@param text string
---@return void
function TextEventListener:on_append_text(text)
    self._text = self._text .. text
    self:on_edit(self._text)
end

---@return string
function TextEventListener:get_text()
    return self._text
end

---@param text string
---@return void
function TextEventListener:set_text(text)
    self._text = text
end

---@return number
function TextEventListener:get_text_length()
    return utf8.len(self._text)
end

---@class TextEventManager: EventManager
local TextEventManager = class("TextEventManager", EventManager)

---@return void
function TextEventManager:init()
    EventManager.init(self, TextEventListener)
    self:set_text_input(false)
    love.keyboard.setKeyRepeat(true)
end

---@param text string
---@return void
function TextEventManager:text_input(text)
    self:invoke_event(TextEventListener.on_append_text, text)
end

---@param key string
---@return void
function TextEventManager:key_pressed(key)
    if not self:is_text_input() then
        return
    end
    if key == "backspace" then
        if love.keyboard.isDown("lctrl", "rctrl") then
            self:invoke_event(TextEventListener.on_remove_word)
        else
            self:invoke_event(TextEventListener.on_remove_characters, 1)
        end
    elseif key == "return" then
        self:invoke_event(TextEventListener.on_enter)
    end
end

---@param value boolean
---@return void
function TextEventManager:set_text_input(value)
    love.keyboard.setTextInput(value)
end

---@return boolean
function TextEventManager:is_text_input()
    return love.keyboard.hasTextInput()
end

return {
    Listener = TextEventListener,
    Manager = TextEventManager
}

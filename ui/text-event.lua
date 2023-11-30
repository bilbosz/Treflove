local EventManager = require("events.event-manager")

---@class TextEventListener
local TextEventListener = class("TextEventListener")

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

function TextEventListener:init()
    self.text = ""
end

function TextEventListener:on_edit(text)

end

function TextEventListener:on_enter()

end

function TextEventListener:on_remove_empty()

end

function TextEventListener:on_remove_characters(characterNumber)
    local offset = utf8.offset(self.text, -characterNumber)
    if self.text == "" and characterNumber > 0 then
        self:on_remove_empty()
    elseif offset then
        self.text = string.sub(self.text, 1, offset - 1)
        self:on_edit(self.text)
    end
end

function TextEventListener:on_remove_word()
    if self.text == "" then
        self:on_remove_empty()
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
        self:on_edit(self.text)
    end
end

function TextEventListener:on_append_text(text)
    self.text = self.text .. text
    self:on_edit(self.text)
end

function TextEventListener:get_text()
    return self.text
end

function TextEventListener:set_text(text)
    self.text = text
end

function TextEventListener:get_text_length()
    return utf8.len(self.text)
end

---@class TextEventManager: EventManager
local TextEventManager = class("TextEventManager", EventManager)

function TextEventManager:init()
    EventManager.init(self, TextEventListener)
    self:set_text_input(false)
    love.keyboard.setKeyRepeat(true)
end

function TextEventManager:text_input(text)
    self:invoke_event(TextEventListener.on_append_text, text)
end

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

function TextEventManager:set_text_input(value)
    love.keyboard.setTextInput(value)
end

function TextEventManager:is_text_input()
    return love.keyboard.hasTextInput()
end

return {
    Listener = TextEventListener,
    Manager = TextEventManager
}

local Event = require("events.event")
local utf8 = require("utf8")

---Editable text composed into a text field (see `TextInput`): holds the text
---and the UTF-8 aware editing operations, and announces the result on its own
---events. The owner registers its methods on them, e.g.
---`buffer.edited:register(self, self.on_edit)`.
---
---The buffer knows nothing about keys; the owning control calls the editing
---operations from its `TextEventManager` handlers, which lets it filter or
---replace an edit (e.g. `NumberInput` rejects non-numeric text).
---@class TextBuffer: Object
---@field public edited Event Triggered with (text) after the text changed by an edit
---@field public removed_empty Event Triggered when removing from an already empty text
---@field private _text string
local TextBuffer = class("TextBuffer")

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

function TextBuffer:init()
    self.edited = Event()
    self.removed_empty = Event()
    self._text = ""
end

---Remove the last `character_number` characters (not bytes).
---@param character_number number
function TextBuffer:remove_characters(character_number)
    local offset = utf8.offset(self._text, -character_number)
    if self._text == "" and character_number > 0 then
        self.removed_empty:trigger()
    elseif offset then
        self._text = string.sub(self._text, 1, offset - 1)
        self.edited:trigger(self._text)
    end
end

---Remove everything after the last whitespace character (the whole text if
---there is none).
function TextBuffer:remove_word()
    if self._text == "" then
        self.removed_empty:trigger()
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
        self.edited:trigger(self._text)
    end
end

---@param text string
function TextBuffer:append_text(text)
    self._text = self._text .. text
    self.edited:trigger(self._text)
end

---@return string
function TextBuffer:get_text()
    return self._text
end

---Replace the text without triggering `edited`.
---@param text string
function TextBuffer:set_text(text)
    self._text = text
end

---@return number
function TextBuffer:get_text_length()
    return utf8.len(self._text)
end

return TextBuffer

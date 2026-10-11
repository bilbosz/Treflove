local Event = require("events.event")

---Turns LÖVE text input and editing keys into events for the focused text
---field. A field registers its methods while it has focus, e.g.
---`app.text_event_manager.text_appended:register(self, self.on_append_text)`,
---and applies them to its own `TextBuffer` (the manager holds no text).
---
---- `text_input(text)` (from `love.textinput`) triggers `text_appended` (text);
---- `key_pressed(key)` (from `love.keypressed`), only while text input is
---  active: backspace triggers `characters_removed` (1), ctrl+backspace
---  `word_removed`, return `entered`.
---
---`set_text_input`/`is_text_input` switch and query LÖVE text input, which
---`KeyboardManager` also consults to suppress plain key events while typing.
---All keyboard access goes through the injected `love.keyboard` backend so
---tests can pass a fake.
---@class TextEventManager
---@field public text_appended Event Triggered with (text) typed by the user
---@field public characters_removed Event Triggered with (character_number) to remove from the end
---@field public word_removed Event Triggered when the last word should be removed
---@field public entered Event Triggered when return is pressed
---@field private _keyboard love.keyboard
local TextEventManager = class("TextEventManager")

---@param keyboard love.keyboard|nil Keyboard backend; defaults to `love.keyboard`
function TextEventManager:init(keyboard)
    self.text_appended = Event()
    self.characters_removed = Event()
    self.word_removed = Event()
    self.entered = Event()
    self._keyboard = keyboard or love.keyboard
    self:set_text_input(false)
    self._keyboard.setKeyRepeat(true)
end

---@param text string
function TextEventManager:text_input(text)
    self.text_appended:trigger(text)
end

---@param key love.KeyConstant
function TextEventManager:key_pressed(key)
    if not self:is_text_input() then
        return
    end
    if key == "backspace" then
        if self._keyboard.isDown("lctrl", "rctrl") then
            self.word_removed:trigger()
        else
            self.characters_removed:trigger(1)
        end
    elseif key == "return" then
        self.entered:trigger()
    end
end

---@param value boolean
function TextEventManager:set_text_input(value)
    self._keyboard.setTextInput(value)
end

---@return boolean
function TextEventManager:is_text_input()
    return self._keyboard.hasTextInput()
end

return TextEventManager

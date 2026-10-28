local utf8 = require("utf8")
local Event = require("events.event")

---@alias TextDirection -1|1 Backward (toward the start) or forward
---@alias TextStep "character"|"word"|"line"

---@class TextEventManager: Object
---@field public text_appended Event Triggered with (text) typed by the user
---@field public commanded Event Triggered with (command: TextCommand, direction: TextDirection|nil, step: TextStep|nil, extend: boolean|nil)
---@field private _keyboard love.keyboard
---@field private _system love.system|nil The backend given; `love.system` when nil, read at the call
local TextEventManager = class("TextEventManager")

---@enum TextCommand
TextEventManager.Command = {
    MOVE = "move",
    DELETE = "delete",
    SELECT_ALL = "select_all",
    COPY = "copy",
    CUT = "cut",
    PASTE = "paste",
    UNDO = "undo",
    REDO = "redo",
    ENTER = "enter"
}

local Command = TextEventManager.Command

---@type table<love.KeyConstant, TextCommand>
local CTRL_COMMANDS = {
    a = Command.SELECT_ALL,
    c = Command.COPY,
    x = Command.CUT,
    v = Command.PASTE,
    y = Command.REDO
}

---@type table<love.KeyConstant, TextDirection>
local MOVE_KEYS = {
    left = -1,
    right = 1
}

---@type table<love.KeyConstant, TextDirection>
local LINE_KEYS = {
    home = -1,
    ["end"] = 1
}

---@type table<love.KeyConstant, TextDirection>
local DELETE_KEYS = {
    backspace = -1,
    delete = 1
}

---@type table<love.KeyConstant, boolean>
local ENTER_KEYS = {
    ["return"] = true,
    kpenter = true
}

---@param keyboard love.keyboard|nil `love.keyboard` by default (setTextInput, hasTextInput, setKeyRepeat)
---@param system love.system|nil `love.system` by default (the clipboard), read at the call
function TextEventManager:init(keyboard, system)
    self.text_appended = Event()
    self.commanded = Event()
    self._keyboard = keyboard or love.keyboard
    self._system = system
    self:set_text_input(false)
    self._keyboard.setKeyRepeat(true)
end

---@param text string
function TextEventManager:text_input(text)
    if self:_is_command_chord() then
        return
    end
    self.text_appended:trigger(text)
end

---@param key love.KeyConstant
function TextEventManager:key_pressed(key)
    if not self:is_text_input() then
        return
    end
    local keyboard_manager = app.keyboard_manager
    if MOVE_KEYS[key] then
        self.commanded:trigger(Command.MOVE, MOVE_KEYS[key], keyboard_manager:is_ctrl_down() and "word" or "character", keyboard_manager:is_shift_down())
    elseif LINE_KEYS[key] then
        self.commanded:trigger(Command.MOVE, LINE_KEYS[key], "line", keyboard_manager:is_shift_down())
    elseif DELETE_KEYS[key] then
        self.commanded:trigger(Command.DELETE, DELETE_KEYS[key], keyboard_manager:is_ctrl_down() and "word" or "character")
    elseif ENTER_KEYS[key] then
        self.commanded:trigger(Command.ENTER)
    elseif key == "z" and self:_is_command_chord() then
        self.commanded:trigger(keyboard_manager:is_shift_down() and Command.REDO or Command.UNDO)
    elseif CTRL_COMMANDS[key] and self:_is_command_chord() then
        self.commanded:trigger(CTRL_COMMANDS[key])
    end
end

---@private
---@return boolean Ctrl is held and right alt is not: Windows reports AltGr, which types letters such as "ą", as left ctrl with right alt
function TextEventManager:_is_command_chord()
    local keyboard_manager = app.keyboard_manager
    return keyboard_manager:is_ctrl_down() and not keyboard_manager:is_key_down("ralt")
end

---@param value boolean
function TextEventManager:set_text_input(value)
    self._keyboard.setTextInput(value)
end

---@return boolean
function TextEventManager:is_text_input()
    return self._keyboard.hasTextInput()
end

---@param text string
function TextEventManager:set_clipboard(text)
    (self._system or love.system).setClipboardText(text)
end

---@return string The clipboard's text with every "\r" dropped and every "\n" replaced by a space; "" when it is not valid UTF-8
function TextEventManager:get_clipboard()
    local text = string.gsub(string.gsub((self._system or love.system).getClipboardText(), "\r", ""), "\n", " ")
    if not utf8.len(text) then
        return ""
    end
    return text
end

return TextEventManager

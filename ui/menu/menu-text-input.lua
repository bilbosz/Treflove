local MenuEntry = require("ui.menu.menu-entry")
local Control = require("controls.control")
local TextInput = require("ui.text-input")
local Consts = require("app.consts")
local Text = require("controls.text")
local TextEventListener = require("ui.text-event").Listener

---@class MenuTextInput: MenuEntry
---@field private _field_name string
---@field private _input TextInput
---@field private _masked boolean
---@field private _on_enter fun():void
---@field private _screen MenuScreen
local MenuTextInput = class("MenuTextInput", MenuEntry)

---@param screen MenuScreen
---@param field_name string
---@param masked boolean
---@param on_enter fun():void
---@return void
function MenuTextInput:init(screen, field_name, masked, on_enter)
    MenuEntry.init(self)
    self._screen = screen
    self._field_name = field_name
    self._masked = masked
    self._on_enter = on_enter
end

---@param parent Control
---@return Control
function MenuTextInput:create_control(parent)
    local ctrl = Control(parent)
    self.control = ctrl

    local input = TextInput(ctrl, self._screen, Consts.MENU_TEXT_INPUT_WIDTH, Consts.MENU_TEXT_INPUT_HEIGHT, self._masked, nil, self._on_enter)
    self._input = input
    input:set_position(Consts.MENU_TEXT_INPUT_FIELD_MARGIN, nil)
    local input_h = ctrl:get_recursive_aabb(input):get_height()

    local text = Text(ctrl, self._field_name, Consts.FOREGROUND_COLOR)
    local text_w, text_h = text:get_size()
    text:set_origin(text_w, text_h * 0.5)
    text:set_position(-Consts.MENU_TEXT_INPUT_FIELD_MARGIN, input_h * 0.5)
    text:set_scale(Consts.MENU_FIELD_SCALE)

    return ctrl
end

---@return string
function MenuTextInput:get_text()
    return TextEventListener.get_text(self._input)
end

return MenuTextInput

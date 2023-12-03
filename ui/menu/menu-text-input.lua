local MenuEntry = require("ui.menu.menu-entry")
local Control = require("controls.control")
local TextInput = require("ui.text-input")
local Consts = require("app.consts")
local Text = require("controls.text")

---@class MenuTextInput: MenuEntry
local MenuTextInput = class("MenuTextInput", MenuEntry)

function MenuTextInput:init(screen, field_name, masked, on_enter)
    MenuEntry.init(self)
    self.screen = screen
    self.field_name = field_name
    self.masked = masked
    self.on_enter = on_enter
end

function MenuTextInput:create_control(parent)
    local ctrl = Control(parent)
    self.control = ctrl

    local input = TextInput(ctrl, self.screen, Consts.MENU_TEXT_INPUT_WIDTH, Consts.MENU_TEXT_INPUT_HEIGHT, self.masked, nil, self.on_enter)
    self.input = input
    input:set_position(Consts.MENU_TEXT_INPUT_FIELD_MARGIN, nil)
    local input_h = ctrl:get_recursive_aabb(input):get_height()

    local text = Text(ctrl, self.field_name, Consts.FOREGROUND_COLOR)
    local text_w, text_h = text:get_size()
    text:set_origin(text_w, text_h * 0.5)
    text:set_position(-Consts.MENU_TEXT_INPUT_FIELD_MARGIN, input_h * 0.5)
    text:set_scale(Consts.MENU_FIELD_SCALE)

    return ctrl
end

function MenuTextInput:get_text()
    return self.input:get_text()
end

return MenuTextInput

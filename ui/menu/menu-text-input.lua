local MenuEntry = require("ui.menu.menu-entry")
local Control = require("controls.control")
local TextInput = require("ui.text-input")
local Consts = require("app.consts")
local Text = require("controls.text")

---@class MenuTextInput: MenuEntry
local MenuTextInput = class("MenuTextInput", MenuEntry)

function MenuTextInput:init(screen, fieldName, masked, onEnter)
    MenuEntry.init(self)
    self.screen = screen
    self.fieldName = fieldName
    self.masked = masked
    self.onEnter = onEnter
end

function MenuTextInput:create_control(parent)
    local ctrl = Control(parent)
    self.control = ctrl

    local input = TextInput(ctrl, self.screen, Consts.MENU_TEXT_INPUT_WIDTH, Consts.MENU_TEXT_INPUT_HEIGHT, self.masked, nil, self.onEnter)
    self.input = input
    input:set_position(Consts.MENU_TEXT_INPUT_FIELD_MARGIN, nil)
    local inputH = ctrl:get_recursive_aabb(input):get_height()

    local text = Text(ctrl, self.fieldName, Consts.FOREGROUND_COLOR)
    local textW, textH = text:get_size()
    text:set_origin(textW, textH * 0.5)
    text:set_position(-Consts.MENU_TEXT_INPUT_FIELD_MARGIN, inputH * 0.5)
    text:set_scale(Consts.MENU_FIELD_SCALE)

    return ctrl
end

function MenuTextInput:get_text()
    return self.input:get_text()
end

return MenuTextInput

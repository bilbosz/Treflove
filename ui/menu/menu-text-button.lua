local MenuEntry = require("ui.menu.menu-entry")
local Control = require("controls.control")
local Consts = require("app.consts")
local TextButton = require("ui.text-button")

---@class MenuTextButton: MenuEntry
local MenuTextButton = class("MenuTextButton", MenuEntry)

function MenuTextButton:init(screen, label, cb)
    MenuEntry.init(self)
    self.screen = screen
    self.label = label
    self.cb = cb
end

function MenuTextButton:create_control(parent)
    local ctrl = Control(parent)
    self.control = ctrl
    ctrl:set_scale(Consts.MENU_BUTTON_SCALE)

    local text = TextButton(ctrl, self.screen, self.label, self.cb)
    local w = text:get_size()
    text:set_origin(w * 0.5, 0)

    return ctrl
end

return MenuTextButton

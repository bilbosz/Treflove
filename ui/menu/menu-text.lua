local MenuEntry = require("ui.menu.menu-entry")
local Control = require("controls.control")
local Consts = require("app.consts")
local Text = require("controls.text")

---@class MenuText: MenuEntry
---@field private _text string
local MenuText = class("MenuText", MenuEntry)

---@param screen MenuScreen
---@param text string
function MenuText:init(screen, text)
    MenuEntry.init(self)
    self._text = text
end

---@param parent Control
---@return Control
function MenuText:create_control(parent)
    local ctrl = Control(parent)
    self.control = ctrl
    ctrl:set_scale(Consts.MENU_FIELD_SCALE)

    local text = Text(ctrl, self._text, Consts.FOREGROUND_COLOR)
    local w = text:get_size()
    text:set_origin(w * 0.5, 0)

    return ctrl
end

return MenuText

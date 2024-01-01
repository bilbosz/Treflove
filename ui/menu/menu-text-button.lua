local MenuEntry = require("ui.menu.menu-entry")
local Control = require("controls.control")
local Consts = require("app.consts")
local TextButton = require("ui.text-button")

---@class MenuTextButton: MenuEntry
---@field private _screen MenuScreen
---@field private _label string
---@field private _cb fun():void
local MenuTextButton = class("MenuTextButton", MenuEntry)

---@param screen MenuScreen
---@param label string
---@param cb fun():void
---@return void
function MenuTextButton:init(screen, label, cb)
    MenuEntry.init(self)
    self._screen = screen
    self._label = label
    self._cb = cb
end

---@param parent Control
---@return Control
function MenuTextButton:create_control(parent)
    local ctrl = Control(parent)
    self.control = ctrl
    ctrl:set_scale(Consts.MENU_BUTTON_SCALE)

    local text = TextButton(ctrl, self._screen, self._label, self._cb)
    local w = text:get_size()
    text:set_origin(w * 0.5, 0)

    return ctrl
end

return MenuTextButton

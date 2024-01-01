local Consts = require("app.consts")
local Control = require("controls.control")
local FormScreen = require("ui.form-screen")
local Logo = require("game.logo")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")

---@class MenuScreen: FormScreen
---@field private _background Rectangle
---@field private _entries MenuEntry[]
---@field private _layout Control
---@field private _title string
local MenuScreen = class("MenuScreen", FormScreen)

---@private
---@return void
function MenuScreen:_create_background()
    self._background = Rectangle(self.screen, app.width, app.height, Consts.BACKGROUND_COLOR)
end

---@private
---@return void
function MenuScreen:_create_layout()
    self._layout = Control(self.screen)
end

---@private
---@return void
function MenuScreen:_create_logo()
    local logo = Logo(self._layout)
    logo:set_position(0, 0)
end

---@private
---@return void
function MenuScreen:_create_title()
    local text = Text(self._layout, self._title, Consts.FOREGROUND_COLOR)

    local w, h = text:get_size()
    text:set_origin(w * 0.5, h * 0.5)
    text:set_position(0, 150)
    text:set_scale(Consts.MENU_TITLE_SCALE)
end

---@private
---@return void
function MenuScreen:_center_layout()
    local layout = self._layout
    local aabb = layout:get_recursive_aabb()
    layout:set_origin(0, aabb:get_height() * 0.5)
    layout:set_position(app.width * 0.5, app.height * 0.5)
end

---@private
---@return void
function MenuScreen:_create_entries()
    local y = 250
    for _, entry_def in ipairs(self._entries) do
        local ctrl = entry_def:create_control(self._layout)
        ctrl:set_position(nil, y)
        y = self._layout:get_recursive_aabb(ctrl):get_max_y() + Consts.MENU_ENTRY_VSPACING
    end
end

---@param title string
---@param entries MenuEntry[]
---@return void
function MenuScreen:init(title, entries)
    FormScreen.init(self)
    self._title = title
    self._entries = entries

    self:_create_background()
    self:_create_layout()
    self:_create_logo()
    self:_create_title()
    self:_create_entries()
end

---@return void
function MenuScreen:show()
    FormScreen.show(self)
    self:on_resize(app.width, app.height)
end

---@param w number
---@param h number
---@return void
function MenuScreen:on_resize(w, h)
    self._background:set_size(w, h)
    self:_center_layout()
end

return MenuScreen

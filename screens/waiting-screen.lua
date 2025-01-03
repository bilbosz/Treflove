local Consts = require("app.consts")
local Control = require("controls.control")
local Logo = require("game.logo")
local Rectangle = require("controls.rectangle")
local Screen = require("screens.screen")
local Text = require("controls.text")
local UpdateEventListener = require("events.update-event").Listener

---@class WaitingScreen: Screen, UpdateEventListener
---@field private _background Rectangle
---@field private _layout Control
---@field private _logo Logo
---@field private _message string
---@field private _text Text
local WaitingScreen = class("WaitingScreen", Screen, UpdateEventListener)

---@private
function WaitingScreen:_create_background()
    self._background = Rectangle(self.screen, app.width, app.height, Consts.BACKGROUND_COLOR)
end

---@private
function WaitingScreen:_create_layout()
    self._layout = Control(self.screen)
end

---@private
function WaitingScreen:_create_logo()
    local logo = Logo(self._layout)
    self._logo = logo
    logo:set_position(0, -15)
end

---@private
function WaitingScreen:_create_text()
    local text = Text(self._layout, self._message, Consts.FOREGROUND_COLOR)
    self._text = text
    text:set_position(0, 100)
    local text_w = text:get_size()
    text:set_origin(text_w * 0.5, 0)
    text:set_scale(Consts.MENU_TITLE_SCALE)
end

---@private
function WaitingScreen:_center_layout()
    local layout = self._layout
    local aabb = layout:get_global_recursive_aabb()
    local h = aabb:get_height()
    local s = app.root:get_scale()
    layout:set_position(app.width * 0.5, app.height * 0.5)
    layout:set_origin(0, h * 0.5 / s)
end

---@param message string
function WaitingScreen:init(message)
    Screen.init(self)
    self._message = message

    self:_create_background()
    self:_create_layout()
    self:_create_logo()
    self:_create_text()
    app.update_event_manager:register_listener(self)
end

function WaitingScreen:show()
    Screen.show(self)
    self:on_resize(app.width, app.height)
end

---@param w number
---@param h number
function WaitingScreen:on_resize(w, h)
    self._background:set_size(w, h)
    self:_center_layout()
end

---@param dt number
function WaitingScreen:on_update(dt)
    local logo = self._logo
    logo:set_rotation(logo:get_rotation() + dt)
end

return WaitingScreen

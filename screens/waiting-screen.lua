local Rectangle = require("controls.rectangle")
local Consts = require("app.consts")
local Control = require("controls.control")
local Logo = require("game.logo")
local Text = require("controls.text")
local Screen = require("screens.screen")
local UpdateEventListener = require("events.update-event").Listener

---@class WaitingScreen: Screen, UpdateEventListener
local WaitingScreen = class("WaitingScreen", Screen, UpdateEventListener)

local function CreateBackground(self)
    self.background = Rectangle(self.screen, app.width, app.height, Consts.BACKGROUND_COLOR)
end

local function CreateLayout(self)
    self.layout = Control(self.screen)
end

local function CreateLogo(self)
    local logo = Logo(self.layout)
    self.logo = logo
    logo:set_position(0, -15)
end

local function CreateText(self)
    local text = Text(self.layout, self.message, Consts.FOREGROUND_COLOR)
    self.text = text
    text:set_position(0, 100)
    local textW = text:get_size()
    text:set_origin(textW * 0.5, 0)
    text:set_scale(Consts.MENU_TITLE_SCALE)
end

local function CenterLayout(self)
    local layout = self.layout
    local aabb = layout:get_global_recursive_aabb()
    local h = aabb:get_height()
    local s = app.root:get_scale()
    layout:set_position(app.width * 0.5, app.height * 0.5)
    layout:set_origin(0, h * 0.5 / s)
end

function WaitingScreen:init(message)
    Screen.init(self)
    self.message = message

    CreateBackground(self)
    CreateLayout(self)
    CreateLogo(self)
    CreateText(self)
    app.update_event_manager:register_listener(self)
end

function WaitingScreen:show()
    Screen.show(self)
    self:on_resize(app.width, app.height)
end

function WaitingScreen:on_resize(w, h)
    self.background:set_size(w, h)
    CenterLayout(self)
end

function WaitingScreen:on_update(dt)
    local logo = self.logo
    logo:set_rotation(logo:get_rotation() + dt)
end

return WaitingScreen

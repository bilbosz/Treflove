local FormScreen = require("ui.form-screen")
local Rectangle = require("controls.rectangle")
local Control = require("controls.control")
local Consts = require("app.consts")
local Logo = require("game.logo")
local Text = require("controls.text")

---@class MenuScreen: FormScreen
local MenuScreen = class("MenuScreen", FormScreen)

local function CreateBackground(self)
    self.background = Rectangle(self.screen, app.width, app.height, Consts.BACKGROUND_COLOR)
end

local function CreateLayout(self)
    self.layout = Control(self.screen)
end

local function CreateLogo(self)
    local logo = Logo(self.layout)
    logo:set_position(0, 0)
end

local function CreateTitle(self)
    local text = Text(self.layout, self.title, Consts.FOREGROUND_COLOR)

    local w, h = text:get_size()
    text:set_origin(w * 0.5, h * 0.5)
    text:set_position(0, 150)
    text:set_scale(Consts.MENU_TITLE_SCALE)
end

local function CenterLayout(self)
    local layout = self.layout
    local aabb = layout:get_recursive_aabb()
    layout:set_origin(0, aabb:get_height() * 0.5)
    layout:set_position(app.width * 0.5, app.height * 0.5)
end

local function CreateEntries(self)
    local y = 250
    for _, entryDef in ipairs(self.entries) do
        local ctrl = entryDef:create_control(self.layout)
        ctrl:set_position(nil, y)
        y = self.layout:get_recursive_aabb(ctrl):get_max_y() + Consts.MENU_ENTRY_VSPACING
    end
end

function MenuScreen:init(title, entries)
    FormScreen.init(self)
    self.title = title
    self.entries = entries

    CreateBackground(self)
    CreateLayout(self)
    CreateLogo(self)
    CreateTitle(self)
    CreateEntries(self)
end

function MenuScreen:show()
    FormScreen.show(self)
    self:on_resize(app.width, app.height)
end

function MenuScreen:on_resize(w, h)
    self.background:set_size(w, h)
    CenterLayout(self)
end

return MenuScreen

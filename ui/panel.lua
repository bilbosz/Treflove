local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Control = require("controls.control")
local Rectangle = require("controls.rectangle")

---@class Panel: ClippingRectangle
local Panel = class("Panel", ClippingRectangle)

local function CreateBackground(self)
    local w, h = self:get_size()
    self.background = Rectangle(self, w, h, Consts.BACKGROUND_COLOR)
end

function Panel:set_size(w, h)
    Control.set_size(self, w, h)
    self.background:set_size(w, h)
end

function Panel:init(parent, width, height)
    ClippingRectangle.init(self, parent, width, height)
    CreateBackground(self)
end

function Panel:on_resize(w, h)
    self:set_size(w, h)
end

return Panel

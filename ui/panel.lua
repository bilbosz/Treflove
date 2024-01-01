local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Control = require("controls.control")
local Rectangle = require("controls.rectangle")

---@class Panel: ClippingRectangle
---@field private _background Rectangle
local Panel = class("Panel", ClippingRectangle)

---@private
---@return void
function Panel:_create_background()
    local w, h = self:get_size()
    self._background = Rectangle(self, w, h, Consts.BACKGROUND_COLOR)
end

---@param w number
---@param h number
---@return void
function Panel:set_size(w, h)
    Control.set_size(self, w, h)
    self._background:set_size(w, h)
end

---@param parent Control
---@param width number
---@param height number
---@return void
function Panel:init(parent, width, height)
    ClippingRectangle.init(self, parent, width, height)
    self:_create_background()
end

---@param w number
---@param h number
---@return void
function Panel:on_resize(w, h)
    self:set_size(w, h)
end

return Panel

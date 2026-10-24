local Control = require("controls.control")

---@class ClippingRectangle: Control
local ClippingRectangle = class("ClippingRectangle", Control)

---@param parent Control|nil
---@param width number
---@param height number
function ClippingRectangle:init(parent, width, height)
    assert(width and height)
    Control.init(self, parent, width, height)
end

function ClippingRectangle:draw()
    local x, y, w, h = love.graphics.getScissor()
    love.graphics.intersectScissor(self:get_global_aabb():get_position_and_size())
    Control.draw(self)
    love.graphics.setScissor(x, y, w, h)
end

---@protected
function ClippingRectangle:_update_own_global_aabb()
    self._global_aabb:set(self:get_global_aabb())
end

return ClippingRectangle

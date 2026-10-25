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
    local min_x, min_y, max_x, max_y = self:get_global_aabb():get_bounds()
    local left, top = math.floor(min_x), math.floor(min_y)
    love.graphics.intersectScissor(left, top, math.ceil(max_x) - left, math.ceil(max_y) - top)
    Control.draw(self)
    love.graphics.setScissor(x, y, w, h)
end

---@protected
function ClippingRectangle:_update_own_global_aabb()
    self._global_aabb:set(self:get_global_aabb())
end

return ClippingRectangle

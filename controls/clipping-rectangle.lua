local Control = require("controls.control")

---@class ClippingRectangle: Control
local ClippingRectangle = class("ClippingRectangle", Control)

---@param parent Control
---@param width number
---@param height number
function ClippingRectangle:init(parent, width, height)
    assert(width and height)
    Control.init(self, parent, width, height)
end

function ClippingRectangle:draw()
    love.graphics.setScissor(self:get_global_aabb():get_position_and_size())
    Control.draw(self)
    love.graphics.setScissor()
end

return ClippingRectangle

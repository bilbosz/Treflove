ClippingRectangle = class("ClippingRectangle", Control)

function ClippingRectangle:Draw()
    local minX, minY, maxX, maxY = self:GetGlobalAabb()
    love.graphics.setScissor(minX, minY, maxX - minX, maxY - minY)
    Control.Draw(self)
    love.graphics.setScissor()
end

function ClippingRectangle:Init(parent, width, height)
    assert(width and height)
    Control.Init(self, parent, width, height)
end

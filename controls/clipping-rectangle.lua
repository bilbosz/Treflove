ClippingRectangle = {}

function ClippingRectangle:Draw()
    local aabb = self:GetAabb()
    love.graphics.setScissor(aabb:GetMinX(), aabb:GetMinY(), aabb:GetWidth(), aabb:GetHeight())
    Control.Draw(self)
    love.graphics.setScissor()
end

function ClippingRectangle:Init(parent, width, height)
    assert(width and height)
    Control.Init(self, parent, width, height)
end

MakeClassOf(ClippingRectangle, Control)

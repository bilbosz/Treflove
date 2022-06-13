ClippingRectangle = {}

function ClippingRectangle:Draw()
    love.graphics.setScissor(self:GetGlobalAabb():GetPositionAndSize())
    Control.Draw(self)
    love.graphics.setScissor()
end

function ClippingRectangle:Init(parent, width, height)
    assert(width and height)
    Control.Init(self, parent, width, height)
end

MakeClassOf(ClippingRectangle, Control)

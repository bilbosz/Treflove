Clipping = class("Clipping", Control)

function Clipping:Draw()
    local minX, minY, maxX, maxY = self:GetGlobalAabb()
    love.graphics.setScissor(minX, minY, maxX - minX, maxY - minY)
    self.Control.Draw(self)
    love.graphics.setScissor()
end

function Clipping:Init(parent, width, height)
    assert(width and height)
    self.Control.Init(self, parent, width, height)
end

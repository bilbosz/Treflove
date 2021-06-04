Clipping = class("Clipping", Control)

function Clipping:Draw()
    local x1, y1 = self.globalTransform:transformPoint(0, 0)
    local x2, y2 = self.globalTransform:transformPoint(self.width, self.height)
    local minX, minY = math.min(x1, x2), math.min(y1, y2)
    local maxX, maxY = math.max(x1, x2), math.max(y1, y2)
    love.graphics.setScissor(minX, minY, maxX - minX, maxY - minY)
    self.Control.Draw(self)
    love.graphics.setScissor()
end

function Clipping:Init(parent, width, height)
    assert(width and height)
    self.Control.Init(self, parent)
    self.width = width
    self.height = height
end

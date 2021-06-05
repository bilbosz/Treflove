Image = class("Image", DrawableControl)

function Image:GetAabb()
    local x1, y1 = self.localTransform:transformPoint(0, 0)
    local x2, y2 = self.localTransform:transformPoint(self:GetDrawable():getDimensions())
    return math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2)
end

function Image:GetSize()
    local minX, minY, maxX, maxY = self:GetAabb()
    return maxX - minX, maxY - minY
end

function Image:Init(parent, path)
    local drawable = love.graphics.newImage(path)
    self.path = path
    self.DrawableControl.Init(self, parent, drawable)
end

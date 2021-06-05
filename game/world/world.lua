World = class("World", Clipping)

function World:CreateBackground()
    local bg = Image(self, self.path)
    self.background = bg
    local bgW, bgH = bg:GetSize()

    local w, h = self:GetSize()

    bg:SetScale(self.scaleToPixelsPerMeter * self.worldWidth / bgW)
    bg:SetOrigin(bgW * 0.5, bgH * 0.5)
    bg:SetPosition(w * 0.5, h * 0.5)
end

function World:CreateWorldCoordinates()
    local bg = self.background
    local bgW = bg:GetSize()
    self.worldCoordinates = Control(self.background)
    self.worldCoordinates:SetScale(bgW / self.worldWidth)
end

function World:Init(parent, width, height, path, worldWidth)
    self.Clipping.Init(self, parent, width, height)
    self.path = path
    self.worldWidth = worldWidth
    self.scaleToPixelsPerMeter = 10
    self.prevMouseX, self.prevMouseY = nil, nil
    self.dragMouseButton = 2
    self.mouseZoomInc = 1.3

    self:CreateBackground()
    self:CreateWorldCoordinates()

    self.rect = Rectangle(self.background, 100, 100)
end

function World:MousePressed(x, y, button)
    local tx, ty = self:TransformToLocal(x, y)
    if tx >= 0 and tx < self.size[1] and ty >= 0 and ty < self.size[2] then
        if button == self.dragMouseButton then
            self.prevMouseX, self.prevMouseY = tx, ty
        end
    end
    self.Control.MousePressed(self, x, y, button)
end

function World:MouseReleased(x, y, button)
    if button == self.dragMouseButton then
        self.prevMouseX, self.prevMouseY = nil, nil
    end
    self.Control.MouseReleased(self, x, y, button)
end

function World:MouseMoved(x, y)
    if self.prevMouseX then
        local tx, ty = self:TransformToLocal(x, y)
        local bg = self.background
        local bgX, bgY = bg:GetPosition()
        bg:SetPosition(bgX + tx - self.prevMouseX, bgY + ty - self.prevMouseY)
        self.prevMouseX, self.prevMouseY = tx, ty
    end
    self.Control.MouseMoved(self, x, y)
end

function World:WheelMoved(x, y)
    local realMouseX, realMouseY = love.mouse.getPosition()
    local selfMouseX, selfMouseY = self:TransformToLocal(realMouseX, realMouseY)
    if selfMouseX >= 0 and selfMouseX < self.size[1] and selfMouseY >= 0 and selfMouseY < self.size[2] then
        local bg = self.background
        local bgMouseX, bgMouseY = bg.globalTransform:inverseTransformPoint(realMouseX, realMouseY)

        local zoomInc = math.pow(self.mouseZoomInc, y)

        bg:SetOrigin(bgMouseX, bgMouseY)
        bg:SetPosition(selfMouseX, selfMouseY)

        local scale = bg:GetScale() * zoomInc
        bg:SetScale(scale)
    end
    self.Control.WheelMoved(self, x, y)
end

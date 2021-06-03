World = class("World", GameObject)

local pixelsPerMeter = 10

function World:Init(anchor, path, width)
    self.path = path
    self.width = width

    local image = love.graphics.newImage(path)
    self.image = image
    local imageW, imageH = image:getDimensions()
    self.imageW, self.imageH = imageW, imageH

    local meterPerPixel = width / imageW
    self.height = meterPerPixel * imageH
    local scale = meterPerPixel * pixelsPerMeter
    -- local positionX, positionY = love.graphics:getWidth() * 0.5 - imageW * 0.5 * scale,
    --     love.graphics:getHeight() * 0.5 - imageH * 0.5 * scale
    local positionX, positionY = 0, 0

    self.transform = love.math.newTransform(positionX, positionY, nil, scale)
end

function World:Draw()
    love.graphics.draw(self.image, self.transform)
end

function World:Update(dt)

end

function World:Zoom(target)
    local oldScale, _, _, oldX, _, _, _, oldY = self.transform:getMatrix()
    local mouseX, mouseY = love.mouse.getPosition()
    local oldTransMouseX, oldTransMouseY = self.transform:transformPoint(mouseX, mouseY)
    local newScale = oldScale * target
    local newTransMouseX, newTransMouseY = oldTransMouseX * target, oldTransMouseY * target

    local positionX, positionY = mouseX / newScale - newTransMouseX, mouseY / newScale - newTransMouseY

    self.transform:setTransformation(positionX, positionY, nil, newScale)
    -- local newTransMouseX, newTransMouseY = 
    -- local positionX, positionY = oldX - transMouseX, oldY - transMouseY
end

function World:MoveImage(dx, dy)
    local scale, _, _, oldX, _, _, _, oldY = self.transform:getMatrix()
    local newX, newY = oldX + dx, oldY + dy
    self.transform:setTransformation(newX, newY, nil, scale)
end

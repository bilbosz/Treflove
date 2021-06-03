Rectangle = class("Rectangle", Control)

function Rectangle:Draw()
    love.graphics.push()
    love.graphics.setColor(unpack(self.color))
    do
        love.graphics.replaceTransform(self.globalTransform)
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    end
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.pop()
    self.Control.Draw(self)
end

function Rectangle:Init(parent, width, height, color)
    self.Control.Init(self, parent)
    self.width = width
    self.height = height
    self.color = color or {0, 0, 0, 0}
end

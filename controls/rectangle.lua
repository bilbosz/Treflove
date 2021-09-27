Rectangle = {}

function Rectangle:Draw()
    love.graphics.push()
    love.graphics.setColor(unpack(self.color))
    do
        love.graphics.replaceTransform(self.globalTransform)
        love.graphics.rectangle("fill", 0, 0, unpack(self.size))
    end
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.pop()
    Control.Draw(self)
end

function Rectangle:Init(parent, width, height, color)
    assert(width and height)
    Control.Init(self, parent, width, height)
    self.color = color or {255, 255, 255, 255}
end

MakeClass(Rectangle, Control)
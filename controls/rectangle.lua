Rectangle = {}

function Rectangle:SetColor(color)
    self.color = color
end

function Rectangle:GetColor()
    return self.color
end

function Rectangle:Draw()
    love.graphics.push()
    love.graphics.setColor(unpack(self.color))
    do
        love.graphics.replaceTransform(self.globalTransform)
        love.graphics.rectangle(self.mode, 0, 0, unpack(self.size))
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
    Control.Draw(self)
end

function Rectangle:Init(parent, width, height, color, borderOnly)
    assert(width and height)
    Control.Init(self, parent, width, height)
    self.color = color or {
        1,
        1,
        1,
        1
    }
    self.mode = borderOnly and "line" or "fill"
end

MakeClassOf(Rectangle, Control)

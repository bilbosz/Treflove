Circle = {}

function Circle:Init(parent, radius, color, lineWidth)
    local r = radius
    local d = r * 2
    local w = lineWidth

    DrawableControl.Init(self, parent, d, d, function()
        love.graphics.setColor(color)
        love.graphics.setLineWidth(w)
        love.graphics.circle("line", r, r, r)
    end)

    self.radius = r
    self.diameter = d
    self.lineWidth = w
    self.color = color
end

function Circle:SetRadius(radius)
    local r = radius
    local d = r * 2
    local w = self.lineWidth
    local color = self.color

    Control.SetSize(self, d, d)
    self:SetDrawCb(function()
        love.graphics.setColor(color)
        love.graphics.setLineWidth(w)
        love.graphics.circle("line", r, r, r)
    end)

    self.radius = r
    self.diameter = d
end

MakeClassOf(Circle, DrawableControl)

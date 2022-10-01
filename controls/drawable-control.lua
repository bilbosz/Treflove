DrawableControl = {}

function DrawableControl:Draw()
    love.graphics.push()
    love.graphics.replaceTransform(self.globalTransform)
    love.graphics.setColor(1, 1, 1, 1)
    self.drawCb()
    love.graphics.pop()
    Control.Draw(self)
end

function DrawableControl:Init(parent, width, height, drawCb)
    Control.Init(self, parent, width, height)
    assert(drawCb)
    self.drawCb = drawCb
end

function DrawableControl:SetDrawCb(drawCb)
    self.drawCb = drawCb
end

MakeClassOf(DrawableControl, Control)

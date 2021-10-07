DrawableControl = {}

function DrawableControl:Draw()
    love.graphics.push()
    love.graphics.replaceTransform(self.globalTransform)
    self.drawCb()
    love.graphics.pop()
    Control.Draw(self)
end

function DrawableControl:Init(parent, width, height, drawCb)
    Control.Init(self, parent, width, height)
    assert(drawCb)
    self.drawCb = drawCb
end

Loader:LoadClass("controls/control.lua")
MakeClassOf(DrawableControl, Control)
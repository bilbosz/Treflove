DrawableControl = class("DrawableControl", Control)

function DrawableControl:Draw()
    love.graphics.draw(self.drawable, self.globalTransform)
    self.Control.Draw(self)
end

function DrawableControl:Init(parent, drawable)
    self.Control.Init(self, parent)
    assert(drawable)
    self.drawable = drawable
end

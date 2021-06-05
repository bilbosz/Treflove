DrawableControl = class("DrawableControl", Control)

function DrawableControl:GetDrawable()
    return self.drawable
end

function DrawableControl:Draw()
    love.graphics.draw(self.drawable, self.globalTransform)
    self.Control.Draw(self)
end

function DrawableControl:Init(parent, drawable)
    self.Control.Init(self, parent, drawable:getDimensions())
    assert(drawable)
    self.drawable = drawable
end

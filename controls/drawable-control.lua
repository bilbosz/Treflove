DrawableControl = class("DrawableControl", Control)

function DrawableControl:GetDrawable()
    return self.drawable
end

function DrawableControl:Draw()
    love.graphics.draw(self.drawable, self.globalTransform)
    Control.Draw(self)
end

function DrawableControl:Init(parent, drawable)
    Control.Init(self, parent, drawable:getDimensions())
    assert(drawable)
    self.drawable = drawable
end

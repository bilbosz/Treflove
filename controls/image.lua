Image = class("Image", DrawableControl)

function Image:Init(parent, path)
    local drawable = love.graphics.newImage(path)
    self.DrawableControl.Init(self, parent, drawable)
end

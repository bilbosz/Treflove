Image = {}

function Image:Init(parent, path)
    local drawable = love.graphics.newImage(path)
    DrawableControl.Init(self, parent, drawable)
end

MakeClass(Image, DrawableControl)
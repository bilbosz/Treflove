Image = {}

function Image:Init(parent, path)
    local image = love.graphics.newImage(Asset(path):GetPath() or path)
    local w, h = image:getDimensions()
    DrawableControl.Init(self, parent, w, h, function()
        love.graphics.draw(image)
    end)
end

MakeClassOf(Image, DrawableControl)

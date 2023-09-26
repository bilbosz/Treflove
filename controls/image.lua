Image = {}

function Image:Init(parent, pathOrLoveImage)
    local loveImage
    if type(pathOrLoveImage) == "string" then
        loveImage = love.graphics.newImage(Asset(pathOrLoveImage):GetPath() or pathOrLoveImage)
    else
        loveImage = pathOrLoveImage
    end
    local w, h = loveImage:getDimensions()
    DrawableControl.Init(self, parent, w, h, function()
        love.graphics.draw(loveImage)
    end)
end

MakeClassOf(Image, DrawableControl)

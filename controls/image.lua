Image = {}

function Image:Init(parent, path)
    local drawable = love.graphics.newImage(path)
    DrawableControl.Init(self, parent, drawable)
end

Loader:LoadClass("controls/drawable-control.lua")
MakeClassOf(Image, DrawableControl)
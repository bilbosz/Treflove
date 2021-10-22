Text = {}

function Text:Init(parent, text)
    local font = love.graphics.newFont(20, "normal", love.graphics.getDPIScale() * 15)
    local textDrawable = love.graphics.newText(font, {{1, 1, 1}, text})
    local w, h = textDrawable:getDimensions()

    DrawableControl.Init(self, parent, w, h, function()
        love.graphics.draw(textDrawable)
    end)
end

Loader.LoadFile("controls/drawable-control.lua")
MakeClassOf(Text, DrawableControl)

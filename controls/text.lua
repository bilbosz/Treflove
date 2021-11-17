Text = {}

function Text:Init(parent, text, color)
    local font = love.graphics.newFont(20, "normal", love.graphics.getDPIScale() * 15)
    color = color or {
        1,
        1,
        1
    }
    local textDrawable = love.graphics.newText(font, text)
    local w, h = textDrawable:getDimensions()

    DrawableControl.Init(self, parent, w, h, function()
        love.graphics.setColor(color)
        love.graphics.draw(textDrawable)
    end)
end

MakeClassOf(Text, DrawableControl)

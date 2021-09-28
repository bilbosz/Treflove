Text = {}

function Text:Init(parent, text)
    local font = love.graphics.newFont(20, "normal", love.graphics.getDPIScale() * 15)

    local textDrawable = love.graphics.newText(font, {{1, 1, 1}, text})
    DrawableControl.Init(self, parent, textDrawable)
end

MakeClassOf(Text, DrawableControl)
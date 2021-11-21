Text = {}

function Text:SetColor(color)
    self.color = color
end

function Text:GetColor()
    return self.color
end

function Text:Init(parent, text, color)
    local font = love.graphics.newFont(20, "normal", love.graphics.getDPIScale() * 15)
    self.color = color or {
        1,
        1,
        1
    }
    local textDrawable = love.graphics.newText(font, text)
    local w, h = textDrawable:getDimensions()

    DrawableControl.Init(self, parent, w, h, function()
        love.graphics.setColor(self.color)
        love.graphics.draw(textDrawable)
    end)
end

MakeClassOf(Text, DrawableControl)

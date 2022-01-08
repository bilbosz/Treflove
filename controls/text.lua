Text = {}

function Text:SetColor(color)
    self.color = color
end

function Text:GetColor()
    return self.color
end

function Text:SetText(text)
    local textDrawable = love.graphics.newText(self.font, text)
    self.textDrawable = textDrawable

    local w, h = textDrawable:getDimensions()
    w, h = w or 0, h or 0
    self:SetSize(w, h)
end

function Text:GetText()
    return self.text
end

function Text:Init(parent, text, color, font)
    self.font = font or Consts.DISPLAY_FONT
    DrawableControl.Init(self, parent, 0, 0, function()
        love.graphics.setColor(self.color)
        love.graphics.draw(self.textDrawable)
    end)

    self.color = color or {
        1,
        1,
        1
    }
    self:SetText(text)
end

MakeClassOf(Text, DrawableControl)

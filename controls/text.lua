local Consts = require("app.consts")

local DrawableControl = require("controls.drawable-control")

---@class Text: DrawableControl
---@field private _text string
---@field private _font LoveFont|nil
---@field private _color number[]
---@field private _text_drawable LoveText
local Text = class("Text", DrawableControl)

---@param parent Control
---@param text string
---@param color number[]
---@param font LoveFont
function Text:init(parent, text, color, font)
    self._font = font or Consts.DISPLAY_FONT
    DrawableControl.init(self, parent, 0, 0, function()
        love.graphics.setColor(self._color)
        love.graphics.draw(self._text_drawable)
    end)

    self._color = color or {
        1,
        1,
        1
    }
    self:set_text(text)
end

---@param color number[]
function Text:set_color(color)
    self._color = color
end

---@return number[]
function Text:get_color()
    return self._color
end

---@param text string
function Text:set_text(text)
    assert_type(text, "string")
    self._text = text
    local text_drawable = love.graphics.newText(self._font, text)
    self._text_drawable = text_drawable

    local w, h = text_drawable:getDimensions()
    w, h = w or 0, h or 0
    self:set_size(w, h)
end

---@return string
function Text:get_text()
    return self._text
end

return Text

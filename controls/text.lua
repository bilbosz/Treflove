local fonts = require("graphics.fonts")

local DrawableControl = require("controls.drawable-control")

local REFERENCE_SIZE = fonts.REFERENCE_SIZE

---@class Text: DrawableControl
---@field private _text string
---@field private _face fonts.Face
---@field private _color number[]
---@field private _text_drawable love.Text
---@field private _pixel_size number The size the drawable's font is rasterized at
local Text = class("Text", DrawableControl)

---@private
function Text:_draw()
    local scale, is_axis_aligned, tx, ty = self:get_screen_placement()
    local px = fonts.pixel_size(scale)
    if px ~= self._pixel_size then
        self._pixel_size = px
        self._text_drawable:setFont(fonts.get(self._face, px))
    end

    love.graphics.setColor(self._color)
    if is_axis_aligned then
        -- One glyph texel per screen pixel, at a whole-pixel position; the
        -- rounding of the font size is absorbed by the layout, not resampled
        local k = scale * REFERENCE_SIZE / px
        if math.abs(scale * REFERENCE_SIZE - px) <= 0.5 then
            k = 1
        end
        love.graphics.origin()
        love.graphics.translate(math.floor(tx + 0.5), math.floor(ty + 0.5))
        love.graphics.scale(k)
    else
        love.graphics.scale(REFERENCE_SIZE / px)
    end
    love.graphics.draw(self._text_drawable)
end

---@param parent Control|nil
---@param text string
---@param color number[]|nil
---@param face fonts.Face|nil The display font by default
function Text:init(parent, text, color, face)
    self._face = face or fonts.Kind.DISPLAY
    DrawableControl.init(self, parent, 0, 0, function()
        self:_draw()
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
    local text_drawable = love.graphics.newText(fonts.reference(self._face), text)
    self._text_drawable = text_drawable
    self._pixel_size = REFERENCE_SIZE

    local w, h = text_drawable:getDimensions()
    w, h = w or 0, h or 0
    self:set_size(w, h)
end

---@param face fonts.Face
function Text:set_font(face)
    self._face = face
    self:set_text(self._text)
end

---@return string
function Text:get_text()
    return self._text
end

---@return number The line height of the font, in model units
function Text:get_font_height()
    return fonts.reference(self._face):getHeight()
end

return Text

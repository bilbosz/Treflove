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
---@return number The pixel size the text is rasterized at for its global transform
---@return number The scale the drawable is drawn at: over the screen when axis-aligned, over the global transform otherwise
---@return boolean Whether the text is drawn axis-aligned
---@return number, number The screen position
function Text:_get_rasterization()
    local scale, is_axis_aligned, tx, ty = self:get_screen_placement()
    local px = fonts.pixel_size(scale)
    if not is_axis_aligned then
        return px, REFERENCE_SIZE / px, false, tx, ty
    end
    -- One glyph texel per screen pixel when the size rounds within half a
    -- pixel: the rounding of the font size is absorbed by the layout, not
    -- resampled
    if math.abs(scale * REFERENCE_SIZE - px) <= 0.5 then
        return px, 1, true, tx, ty
    end
    return px, scale * REFERENCE_SIZE / px, true, tx, ty
end

---@private
function Text:_draw()
    local px, k, is_axis_aligned, tx, ty = self:_get_rasterization()
    if px ~= self._pixel_size then
        self._pixel_size = px
        self._text_drawable:setFont(fonts.get(self._face, px))
    end

    love.graphics.setColor(self._color)
    if is_axis_aligned then
        love.graphics.origin()
        love.graphics.translate(math.floor(tx + 0.5), math.floor(ty + 0.5))
    end
    love.graphics.scale(k)
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

---@param text string
---@return number The width of `text` as the text draws it, in model units before the control's scale: measured in the font rasterized for the text's size on screen, whose hinted advances the reference font scaled down would miss by a glyph over a line
function Text:measure(text)
    local scale, is_axis_aligned = self:get_screen_placement()
    local px, k = self:_get_rasterization()
    local units = is_axis_aligned and k / scale or k
    return fonts.get(self._face, px):getWidth(text) * units
end

---@return number The line height of the font, in model units
function Text:get_font_height()
    return fonts.reference(self._face):getHeight()
end

return Text

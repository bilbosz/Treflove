local Consts = require("app.consts")
local Control = require("controls.control")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")
local TextInput = require("ui.text-input")
local fonts = require("graphics.fonts")
local lifetime = require("lifetime")

---@class PreviewFontArea: Control
---@field _preview_area PreviewArea
---@field private _data media.Source The font file, the face of the field and the sample
---@field private _sample Control The sample's lines, under the strip in the drawing order
---@field private _strip Rectangle
---@field private _input TextInput
local PreviewFontArea = class("PreviewFontArea", Control)

---@private
---@return number
function PreviewFontArea:_get_strip_height()
    return Consts.PANEL_TEXT_INPUT_HEIGHT + 2 * Consts.PADDING
end

---@private
function PreviewFontArea:_create_strip()
    local area_w, area_h = self._preview_area:get_size()
    local strip_h = self:_get_strip_height()
    local strip = Rectangle(self, area_w, strip_h, Consts.BACKGROUND_COLOR)
    self._strip = strip
    strip:set_position(-area_w * 0.5, area_h * 0.5 - strip_h)

    local input = TextInput(strip, self._preview_area:get_form_screen(), area_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, false, function()
        self:_update_sample()
    end)
    self._input = input
    input:set_position(Consts.PADDING, Consts.PADDING)
    input:set_font(self._data)
    input:set_text(Consts.FONT_PREVIEW_TEXT)
end

---@private
function PreviewFontArea:_destroy_sample_lines()
    for _, line in ipairs(self._sample:get_children()) do
        lifetime.destroy(line)
    end
end

---@private
function PreviewFontArea:_update_sample()
    self:_destroy_sample_lines()

    local area_w, area_h = self._preview_area:get_size()
    local scale = Consts.FONT_PREVIEW_SAMPLE_SCALE
    local font = fonts.reference(self._data)
    local _, wrapped = font:getWrap(self._input:get_text(), (area_w - 2 * Consts.PADDING) / scale)
    local line_h = font:getHeight() * scale

    local bottom = area_h * 0.5 - self:_get_strip_height() - Consts.PADDING
    local y = -area_h * 0.5 + Consts.PADDING
    for _, str in ipairs(wrapped) do
        if y + line_h > bottom then
            return
        end
        local line = Text(self._sample, str, Consts.TEXT_INPUT_FOREGROUND_COLOR, self._data)
        line:set_scale(scale)
        local line_w = line:get_outer_size()
        line:set_position(-line_w * 0.5, y)
        y = y + line_h
    end
end

---@param preview_area PreviewArea
---@param medium love.Font Unused: the face is made of `data` at every size the texts draw at
---@param data media.Source
function PreviewFontArea:init(preview_area, medium, data)
    self._preview_area = preview_area
    self._data = data
    Control.init(self, preview_area.content_parent)
    self._sample = Control(self)
    self:_create_strip()
    self:_update_sample()
end

---@param reason lifetime.Reason
function PreviewFontArea:release(reason)
    fonts.forget(self._data)
    Control.release(self, reason)
end

return PreviewFontArea

local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")
local fonts = require("graphics.fonts")

---@class SelectionBoxRow: Rectangle
---@field private _title Text
---@field private _is_highlighted boolean
---@field private _is_selected boolean
local SelectionBoxRow = class("SelectionBoxRow", Rectangle)

---@param parent Control
---@param clip_width number
---@param height number
---@param title string
---@return Text The title at the padding, vertically centered, in a clip `clip_width` wide that cuts a longer one
function SelectionBoxRow.create_title(parent, clip_width, height, title)
    local clip = ClippingRectangle(parent, math.max(0, clip_width), height)
    clip:set_position(Consts.SELECTION_BOX_PADDING, 0)
    local text = Text(clip, title, Consts.TEXT_INPUT_FOREGROUND_COLOR, fonts.Kind.USER_INPUT)
    text:set_scale(Consts.MENU_FIELD_SCALE)
    text:set_origin(0, text:get_font_height() * 0.5)
    text:set_position(0, height * 0.5)
    return text
end

---@private
function SelectionBoxRow:_update_color()
    ---@type number[]
    local color
    if self._is_selected then
        color = self._is_highlighted and Consts.BUTTON_ACTIVE_HOVER_COLOR or Consts.BUTTON_ACTIVE_COLOR
    else
        color = self._is_highlighted and Consts.BUTTON_HOVER_COLOR or Consts.BUTTON_NORMAL_COLOR
    end
    self:set_color(color)
end

---@param parent Control
---@param width number
---@param height number
---@param title string
function SelectionBoxRow:init(parent, width, height, title)
    Rectangle.init(self, parent, width, height, Consts.BUTTON_NORMAL_COLOR)
    self._title = SelectionBoxRow.create_title(self, width - 2 * Consts.SELECTION_BOX_PADDING, height, title)
    self._is_highlighted = false
    self._is_selected = false
end

---@return string
function SelectionBoxRow:get_title()
    return self._title:get_text()
end

---@param value boolean
function SelectionBoxRow:set_highlighted(value)
    self._is_highlighted = value
    self:_update_color()
end

---@return boolean
function SelectionBoxRow:is_highlighted()
    return self._is_highlighted
end

---@param value boolean Whether the row stands for the box's selected option
function SelectionBoxRow:set_selected(value)
    self._is_selected = value
    self:_update_color()
end

---@return boolean
function SelectionBoxRow:is_selected()
    return self._is_selected
end

return SelectionBoxRow

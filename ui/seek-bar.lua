local Consts = require("app.consts")
local Control = require("controls.control")
local Event = require("events.event")
local Rectangle = require("controls.rectangle")
local Utils = require("utils.utils")

---@class SeekBar: Control
---@field public sought Event Triggered with the fraction the pointer chose, in [0, 1]
---@field private _indicator Rectangle
---@field private _fraction number
---@field private _is_seekable boolean
---@field private _drag_id PointerId The press dragging the indicator, nil when none does
local SeekBar = class("SeekBar", Control)

local LENGTH, THICKNESS, MARGIN = Consts.SCROLL_VIEW_INDICATOR_LENGTH, Consts.SCROLL_VIEW_INDICATOR_THICKNESS, Consts.SCROLL_VIEW_INDICATOR_MARGIN

---@param parent Control|nil
---@param width number
function SeekBar:init(parent, width)
    Control.init(self, parent, width, THICKNESS + 2 * MARGIN)
    self.sought = Event()
    self._fraction = 0
    self._is_seekable = true
    self._drag_id = nil

    local track = Rectangle(self, width, THICKNESS, Consts.MEDIA_PLAYER_TRACK_COLOR)
    track:set_position(0, MARGIN)
    self._indicator = Rectangle(self, LENGTH, THICKNESS, Consts.SCROLL_VIEW_INDICATOR_COLOR)
    self:set_fraction(0)

    local pointer_event_manager = app.pointer_event_manager
    pointer_event_manager.pointer_down:register(self, self.on_pointer_down)
    pointer_event_manager.pointer_up:register(self, self.on_pointer_up)
    pointer_event_manager.pointer_move:register(self, self.on_pointer_move)
end

---@private
---@return number
function SeekBar:_get_travel()
    local width = self:get_size()
    return math.max(0, width - LENGTH)
end

---@param fraction number Clamped to [0, 1]
function SeekBar:set_fraction(fraction)
    self._fraction = Utils.clamp(0, 1, fraction)
    self._indicator:set_position(self._fraction * self:_get_travel(), MARGIN)
end

---@return number
function SeekBar:get_fraction()
    return self._fraction
end

---@param value boolean False hides the indicator and lets presses through
function SeekBar:set_seekable(value)
    self._is_seekable = value
    self._indicator:set_visible(value)
    if not value and self._drag_id then
        self._drag_id = nil
        app.pointer_event_manager:release_capture(self)
    end
end

---@return boolean
function SeekBar:is_seekable()
    return self._is_seekable
end

---@return boolean
function SeekBar:is_dragging()
    return self._drag_id ~= nil
end

---@private
---@param x number
---@param y number
function SeekBar:_seek_to(x, y)
    local lx = self:transform_to_local(x, y)
    local travel = self:_get_travel()
    local fraction = travel > 0 and (lx - LENGTH * 0.5) / travel or 0
    self:set_fraction(fraction)
    self.sought:trigger(self._fraction)
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function SeekBar:on_pointer_down(x, y, id)
    if id ~= Consts.LEFT_MOUSE_BUTTON or not self._is_seekable or self._drag_id then
        return true
    end
    self._drag_id = id
    app.pointer_event_manager:capture(self, id)
    self:_seek_to(x, y)
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function SeekBar:on_pointer_move(x, y, id)
    if not self._drag_id then
        return true
    end
    self:_seek_to(x, y)
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function SeekBar:on_pointer_up(x, y, id)
    if not self._drag_id or id ~= self._drag_id then
        return true
    end
    self._drag_id = nil
end

return SeekBar

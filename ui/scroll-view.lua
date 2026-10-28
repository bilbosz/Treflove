local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Control = require("controls.control")
local Rectangle = require("controls.rectangle")
local Utils = require("utils.utils")

---@class ScrollView: ClippingRectangle
---@field private _content Control What scrolls is parented to it; its size is the scrollable extent
---@field private _scroll [number, number] How far the content is scrolled, in the view's units, never negative
---@field private _vertical_indicator Rectangle|nil With indicators: along the right edge
---@field private _horizontal_indicator Rectangle|nil With indicators: along the bottom edge
---@field private _drag_pos [number, number]|nil The last pointer position of the drag in progress, in the view's coordinates
---@field private _wheel_step number How far a notch of the wheel scrolls, in the view's units
local ScrollView = class("ScrollView", ClippingRectangle)

---@param parent Control|nil
---@param width number
---@param height number
---@param with_indicators boolean|nil Show along each edge the content overflows how far it is scrolled
function ScrollView:init(parent, width, height, with_indicators)
    ClippingRectangle.init(self, parent, width, height)
    self._content = Control(self)
    self._scroll = {
        0,
        0
    }
    self._drag_pos = nil
    self._wheel_step = Consts.SCROLL_VIEW_WHEEL_STEP
    if with_indicators then
        self._vertical_indicator = Rectangle(self, Consts.SCROLL_VIEW_INDICATOR_THICKNESS, Consts.SCROLL_VIEW_INDICATOR_LENGTH, Consts.SCROLL_VIEW_INDICATOR_COLOR)
        self._horizontal_indicator = Rectangle(self, Consts.SCROLL_VIEW_INDICATOR_LENGTH, Consts.SCROLL_VIEW_INDICATOR_THICKNESS, Consts.SCROLL_VIEW_INDICATOR_COLOR)
    end
    self:_update_indicators()

    local pointer_event_manager = app.pointer_event_manager
    pointer_event_manager.pointer_down:register(self, self.on_pointer_down)
    pointer_event_manager.pointer_up:register(self, self.on_pointer_up)
    pointer_event_manager.pointer_move:register(self, self.on_pointer_move)
    pointer_event_manager.wheel:register(self, self.on_wheel)
end

---@return Control The control to parent the scrolled content to
function ScrollView:get_content()
    return self._content
end

---@param width number
---@param height number
function ScrollView:set_content_size(width, height)
    self._content:set_size(width, height)
    self:set_scroll(self._scroll[1], self._scroll[2])
end

---@return number, number
function ScrollView:get_content_size()
    return self._content:get_size()
end

---@return number, number How far the content may be scrolled: what it overflows the view by, zero where it fits
function ScrollView:get_max_scroll()
    local w, h = self:get_size()
    local cw, ch = self._content:get_size()
    return math.max(0, cw - w), math.max(0, ch - h)
end

---@param x number
---@param y number
function ScrollView:set_scroll(x, y)
    local max_x, max_y = self:get_max_scroll()
    self._scroll[1] = Utils.clamp(0, max_x, x)
    self._scroll[2] = Utils.clamp(0, max_y, y)
    self._content:set_position(-self._scroll[1], -self._scroll[2])
    self:_update_indicators()
end

---@return number, number
function ScrollView:get_scroll()
    return self._scroll[1], self._scroll[2]
end

---@param units number How far a notch of the wheel scrolls, in the view's units
function ScrollView:set_wheel_step(units)
    self._wheel_step = units
end

---@return number
function ScrollView:get_wheel_step()
    return self._wheel_step
end

---@return boolean
function ScrollView:is_dragging()
    return self._drag_pos ~= nil
end

---@param width number
---@param height number
function ScrollView:set_size(width, height)
    ClippingRectangle.set_size(self, width, height)
    self:set_scroll(self._scroll[1], self._scroll[2])
end

---@private
function ScrollView:_update_indicators()
    local vertical, horizontal = self._vertical_indicator, self._horizontal_indicator
    if not vertical or not horizontal then
        return
    end
    local w, h = self:get_size()
    local max_x, max_y = self:get_max_scroll()
    local margin, length, thickness = Consts.SCROLL_VIEW_INDICATOR_MARGIN, Consts.SCROLL_VIEW_INDICATOR_LENGTH, Consts.SCROLL_VIEW_INDICATOR_THICKNESS

    vertical:set_visible(max_y > 0)
    if max_y > 0 then
        local track = math.max(0, h - 2 * margin - length)
        vertical:set_position(w - margin - thickness, margin + track * self._scroll[2] / max_y)
    end

    horizontal:set_visible(max_x > 0)
    if max_x > 0 then
        local track = math.max(0, w - 2 * margin - length)
        horizontal:set_position(margin + track * self._scroll[1] / max_x, h - margin - thickness)
    end
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function ScrollView:on_pointer_down(x, y, id)
    if id ~= Consts.SCROLL_VIEW_DRAG_BUTTON or self._drag_pos then
        return true
    end
    self._drag_pos = {
        self:transform_to_local(x, y)
    }
    app.pointer_event_manager:capture(self, id)
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function ScrollView:on_pointer_move(x, y, id)
    local drag_pos = self._drag_pos
    if not drag_pos then
        return true
    end
    local lx, ly = self:transform_to_local(x, y)
    self:set_scroll(self._scroll[1] - (lx - drag_pos[1]), self._scroll[2] - (ly - drag_pos[2]))
    drag_pos[1], drag_pos[2] = lx, ly
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function ScrollView:on_pointer_up(x, y, id)
    if id ~= Consts.SCROLL_VIEW_DRAG_BUTTON or not self._drag_pos then
        return true
    end
    self._drag_pos = nil
end

---@param x number
---@param y number
---@param dx number Positive scrolls toward the content's right
---@param dy number Positive scrolls toward the content's top
---@return boolean|nil
function ScrollView:on_wheel(x, y, dx, dy)
    local step = self._wheel_step
    self:set_scroll(self._scroll[1] + dx * step, self._scroll[2] - dy * step)
end

return ScrollView

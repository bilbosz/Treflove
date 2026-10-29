local Button = require("ui.button")
local Consts = require("app.consts")
local Control = require("controls.control")
local ScrollView = require("ui.scroll-view")
local SelectionBoxRow = require("ui.selection-box-row")
local Utils = require("utils.utils")
local lifetime = require("lifetime")

---@alias SelectionBoxListHandler fun(index: integer|nil) Run when the user ends the list: with the row picked, nil when it is dismissed

---@class SelectionBoxList: Control
---@field private _on_end SelectionBoxListHandler
---@field private _frame Control The list, under or above the box it opened from
---@field private _view ScrollView
---@field private _rows SelectionBoxRow[]
---@field private _row_height number
---@field private _highlighted integer
---@field private _backdrop_button Button
---@field private _frame_button Button
---@field private _is_backdrop_pressed boolean The last press was on the backdrop
---@field private _pressed_row integer|nil The row of the last press on the list
local SelectionBoxList = class("SelectionBoxList", Control)

---@param id PointerId
---@return boolean
local function _is_press(id)
    return type(id) ~= "number" or id == Consts.LEFT_MOUSE_BUTTON
end

---@param frame Control
---@return SelectionBoxList
local function _list_of(frame)
    local list = assert(frame:get_parent())
    assert(is_instance_of(list, SelectionBoxList))
    ---@cast list SelectionBoxList
    return list
end

---@param frame Control
---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
local function _on_frame_pointer_down(frame, x, y, id)
    return _list_of(frame):on_frame_pointer_down(x, y, id)
end

---@param frame Control
---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
local function _on_frame_pointer_move(frame, x, y, id)
    return _list_of(frame):on_frame_pointer_move(x, y, id)
end

---@private
---@param anchor Control
---@param count integer
function SelectionBoxList:_create_frame(anchor, count)
    local min_x, min_y, max_x, max_y = anchor:get_global_aabb():get_bounds()
    local left, top = self:transform_to_local(min_x, min_y)
    local right, bottom = self:transform_to_local(max_x, max_y)
    local width, row_height = right - left, bottom - top
    local height = math.min(count, Consts.SELECTION_BOX_MAX_ROWS) * row_height
    local y = bottom
    if bottom + height > assert(app.height) then
        y = top - height
    end
    self._row_height = row_height

    local frame = Control(self, width, height)
    self._frame = frame
    frame:set_position(left, y)

    local view = ScrollView(frame, width, height, true)
    self._view = view
    view:set_content_size(width, count * row_height)
    view:set_wheel_step(row_height * Consts.SELECTION_BOX_WHEEL_ROWS)
end

---@private
---@param titles string[]
---@param selected integer|nil
function SelectionBoxList:_create_rows(titles, selected)
    local content = self._view:get_content()
    local width = self._frame:get_size()
    local row_height = self._row_height
    self._rows = {}
    for i, title in ipairs(titles) do
        local row = SelectionBoxRow(content, width, row_height, title)
        row:set_position(0, (i - 1) * row_height)
        row:set_selected(i == selected)
        self._rows[i] = row
    end
end

---@private
function SelectionBoxList:_register_events()
    local pointer_event_manager = app.pointer_event_manager
    pointer_event_manager.pointer_down:register(self, self.on_backdrop_pointer_down)
    pointer_event_manager.pointer_down:register(self._frame, _on_frame_pointer_down)
    pointer_event_manager.pointer_move:register(self._frame, _on_frame_pointer_move)
    pointer_event_manager.wheel:register(self, self.on_backdrop_wheel)
    app.resize_manager.resized:register(self, self.on_resize)

    self._backdrop_button = Button()
    self._frame_button = Button()
    self._backdrop_button.selected:register(self, self.on_backdrop_selected)
    self._frame_button.selected:register(self, self.on_frame_selected)
    local button_event_manager = app.button_event_manager
    local frame = self._frame
    button_event_manager:register(self, self._backdrop_button)
    button_event_manager:register(frame, self._frame_button)
    lifetime.hook(function()
        -- a button kept under the pointer or pressed would be driven later
        button_event_manager:unregister(self)
        button_event_manager:unregister(frame)
    end, self)
end

---@param parent Control The form screen's control: the list goes last, over everything of the screen, its own box the backdrop covering the screen
---@param anchor Control What the list opens from: under it, or above it when the rows would run past the bottom of the screen
---@param titles string[] Not empty
---@param selected integer|nil The row of the selected option
---@param on_end SelectionBoxListHandler
function SelectionBoxList:init(parent, anchor, titles, selected, on_end)
    assert(#titles > 0)
    Control.init(self, parent, assert(app.width), assert(app.height))
    self._on_end = on_end
    self._is_backdrop_pressed = false
    self._pressed_row = nil
    self:_create_frame(anchor, #titles)
    self:_create_rows(titles, selected)
    self._highlighted = selected or 1
    self:_highlight(self._highlighted)
    self:_scroll_into_view(self._highlighted)
    self:_register_events()
end

---@private
---@param index integer
function SelectionBoxList:_scroll_into_view(index)
    local view = self._view
    local _, height = view:get_size()
    local _, scroll = view:get_scroll()
    local row_height = self._row_height
    local top = (index - 1) * row_height
    if top < scroll then
        scroll = top
    elseif top + row_height > scroll + height then
        scroll = top + row_height - height
    end
    view:set_scroll(0, scroll)
end

---@private
---@param index integer
function SelectionBoxList:_highlight(index)
    self._rows[self._highlighted]:set_highlighted(false)
    self._highlighted = index
    self._rows[index]:set_highlighted(true)
end

---@private
---@param x number
---@param y number
---@return integer|nil
function SelectionBoxList:_get_row_at(x, y)
    local _, ly = self._view:get_content():transform_to_local(x, y)
    local index = math.floor(ly / self._row_height) + 1
    if index < 1 or index > #self._rows then
        return nil
    end
    return index
end

---@return Control The list over the backdrop
function SelectionBoxList:get_frame()
    return self._frame
end

---@return ScrollView
function SelectionBoxList:get_view()
    return self._view
end

---@return SelectionBoxRow[]
function SelectionBoxList:get_rows()
    return table.copy(self._rows)
end

---@return integer
function SelectionBoxList:get_highlighted()
    return self._highlighted
end

---@param delta integer Rows down, negative up; clamped at the ends
function SelectionBoxList:move_highlight(delta)
    local index = Utils.clamp(1, #self._rows, self._highlighted + delta)
    self:_highlight(index)
    self:_scroll_into_view(index)
end

-- The pointer dispatch runs before the button manager's: a press only
-- records where it landed, and its button's `selected` ends the list, so the
-- manager has the list's button pressed rather than one under the list once
-- the list is gone.

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function SelectionBoxList:on_backdrop_pointer_down(x, y, id)
    self._pressed_row = nil
    if _is_press(id) then
        self._is_backdrop_pressed = true
    else
        self._on_end(nil)
    end
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function SelectionBoxList:on_frame_pointer_down(x, y, id)
    self._is_backdrop_pressed = false
    self._pressed_row = _is_press(id) and self:_get_row_at(x, y) or nil
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function SelectionBoxList:on_frame_pointer_move(x, y, id)
    local index = self:_get_row_at(x, y)
    if index then
        self:_highlight(index)
    end
end

---@param x number
---@param y number
---@param dx number
---@param dy number
---@return boolean|nil
function SelectionBoxList:on_backdrop_wheel(x, y, dx, dy)
end

function SelectionBoxList:on_backdrop_selected()
    if self._is_backdrop_pressed then
        self._on_end(nil)
    end
end

function SelectionBoxList:on_frame_selected()
    local index = self._pressed_row
    if index then
        self._on_end(index)
    end
end

---@param width number
---@param height number
function SelectionBoxList:on_resize(width, height)
    self._on_end(nil)
end

return SelectionBoxList

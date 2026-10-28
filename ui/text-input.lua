local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Control = require("controls.control")
local fonts = require("graphics.fonts")
local FormScreen = require("ui.form-screen")
local Input = require("ui.input")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")
local TextBuffer = require("ui.text-buffer")
local TextEventManager = require("ui.text-event")
local Utils = require("utils.utils")
local lifetime = require("lifetime")
local utf8 = require("utf8")

local Command = TextEventManager.Command

---@class TextInput: Control, Input
---@field private _background Rectangle
---@field private _buffer TextBuffer
---@field private _caret Rectangle
---@field private _caret_time number|nil
---@field private _clicks integer How many presses in a row within the multi-click interval
---@field private _clip ClippingRectangle
---@field private _content Control
---@field private _drag_id PointerId The press whose moves set the caret; nil without one
---@field private _has_new_value boolean
---@field private _is_multivalue boolean
---@field private _masked boolean
---@field private _offset number How far the content is scrolled left, never positive
---@field private _on_enter InputHandler|nil
---@field private _on_input InputHandler|nil
---@field private _padding number
---@field private _press_time number|nil The app time of the last press
---@field private _selection Rectangle
---@field private _text_ctrl Text
local TextInput = class("TextInput", Control, Input)

---@type table<love.CursorType, love.Cursor>
local cursors = {}

---@param kind love.CursorType
local function _set_cursor(kind)
    if not love.mouse.isCursorSupported() then
        return
    end
    local cursor = cursors[kind]
    if not cursor then
        cursor = love.mouse.getSystemCursor(kind)
        cursors[kind] = cursor
    end
    love.mouse.setCursor(cursor)
end

---@param id PointerId
---@return boolean
local function _is_press(id)
    return type(id) ~= "number" or id == Consts.LEFT_MOUSE_BUTTON
end

---@private
function TextInput:_upload_background_view()
    ---@type number[]|nil
    local color
    if self:is_focused() then
        if self:is_multivalue_default() then
            color = Consts.BUTTON_MULTIVALUE_SELECT_COLOR
        else
            color = Consts.BUTTON_SELECT_COLOR
        end
    elseif self:is_hovered() then
        if self:is_multivalue_default() then
            color = Consts.BUTTON_MULTIVALUE_HOVER_COLOR
        else
            color = Consts.BUTTON_HOVER_COLOR
        end
    elseif self:is_read_only() then
        if self:is_multivalue_default() then
            color = Consts.BUTTON_MULTIVALUE_READ_ONLY_COLOR
        else
            color = Consts.BUTTON_READ_ONLY_COLOR
        end
    else
        if self:is_multivalue_default() then
            color = Consts.BUTTON_MULTIVALUE_NORMAL_COLOR
        else
            color = Consts.BUTTON_NORMAL_COLOR
        end
    end
    assert(color ~= nil)
    self._background:set_color(color)
end

---@private
---@param index integer A codepoint count
---@return string What the field shows before the index: the text, or as many bullets
function TextInput:_get_shown_prefix(index)
    if self._masked then
        return string.rep("•", index)
    end
    local text = self:get_text()
    return string.sub(text, 1, assert(utf8.offset(text, index + 1)) - 1)
end

---@private
---@param index integer A codepoint count
---@return number The x of the boundary after `index` codepoints, in the content's units
function TextInput:_get_x_of(index)
    local text = self._text_ctrl
    return text:measure(self:_get_shown_prefix(index)) * text:get_scale()
end

---@private
---@param x number
---@param y number
---@return integer The codepoint boundary nearest to the global point
function TextInput:_get_index_at(x, y)
    local lx = self._content:transform_to_local(x, y)
    if lx <= 0 then
        return 0
    end
    local length = self:get_text_length()
    local prev_x = 0
    for i = 1, length do
        local xi = self:_get_x_of(i)
        if xi >= lx then
            return xi - lx < lx - prev_x and i or i - 1
        end
        prev_x = xi
    end
    return length
end

---@private
function TextInput:_update_text_view()
    self._text_ctrl:set_text(self:_get_shown_prefix(self:get_text_length()))
end

---@private
---@param caret_x number
function TextInput:_scroll_to_caret(caret_x)
    local clip_w = self._clip:get_size()
    local caret_w = Consts.CARET_WIDTH
    local text = self._text_ctrl
    local text_w = text:get_size() * text:get_scale()
    local offset = self._offset
    if caret_x + offset + caret_w > clip_w then
        offset = clip_w - caret_w - caret_x
    end
    if caret_x + offset < 0 then
        offset = -caret_x
    end
    offset = Utils.clamp(-math.max(0, text_w + caret_w - clip_w), 0, offset)
    self._offset = offset
    self._content:set_position(offset, nil)
end

---@private
function TextInput:_upload_caret_view()
    local caret = self._caret
    local is_focused = self:is_focused()
    caret:set_enabled(is_focused)
    if is_focused then
        self._caret_time = 0
    end
    local caret_x = self:_get_x_of(self._buffer:get_caret())
    caret:set_position(caret_x, nil)
    self:_scroll_to_caret(caret_x)
end

---@private
function TextInput:_upload_selection_view()
    local selection = self._selection
    local buffer = self._buffer
    local shown = self:is_focused() and buffer:has_selection()
    selection:set_enabled(shown)
    if not shown then
        return
    end
    local start, finish = buffer:get_selection()
    local start_x, finish_x = self:_get_x_of(start), self:_get_x_of(finish)
    selection:set_position(start_x, nil)
    local _, h = selection:get_size()
    selection:set_size(finish_x - start_x, h)
end

---@private
function TextInput:_update_content_view()
    self:_update_text_view()
    self:_upload_caret_view()
    self:_upload_selection_view()
end

---@private
function TextInput:_update_view()
    if lifetime.dying(self) then -- the view died with the children
        return
    end
    self:_upload_background_view()
    self:_update_content_view()
    self:_update_text_events_registration()
end

---@private
function TextInput:_update_text_events_registration()
    self:_set_text_events_registered(self:is_focused() and self:get_form_screen():is_showed())
end

---@private
---@param value boolean
function TextInput:_set_text_events_registered(value)
    local manager = app.text_event_manager
    if value then
        manager.text_appended:register(self, self.on_append_text)
        manager.commanded:register(self, self.on_command)
    else
        manager.text_appended:unregister(self)
        manager.commanded:unregister(self)
    end
end

---@private
---@param value boolean
function TextInput:_set_pointer_events_registered(value)
    local manager = app.pointer_event_manager
    if value then
        manager.pointer_down:register(self, self.on_pointer_down)
        manager.pointer_move:register(self, self.on_pointer_move)
        manager.pointer_up:register(self, self.on_pointer_up)
    else
        manager.pointer_down:unregister(self)
        manager.pointer_move:unregister(self)
        manager.pointer_up:unregister(self)
        manager:release_capture(self)
        self._drag_id = nil
    end
end

---@private
function TextInput:_create_background()
    local width, height = self:get_size()
    self._background = Rectangle(self, width, height, Consts.BUTTON_NORMAL_COLOR)
end

---@private
function TextInput:_create_clip()
    local width, height = self:get_size()
    local clip = ClippingRectangle(self, width - 2 * self._padding, height)
    self._clip = clip

    clip:set_position(self._padding, 0)
end

---@private
---@return number
function TextInput:_get_caret_height()
    local _, height = self:get_size()
    return height - 2 * self._padding
end

---@private
function TextInput:_create_selection()
    local height = self:_get_caret_height()
    local selection = Rectangle(self._content, 0, height, Consts.TEXT_INPUT_SELECTION_COLOR)
    self._selection = selection

    selection:set_origin(0, height * 0.5)
    selection:set_enabled(false)
end

---@private
function TextInput:_create_caret()
    local height = self:_get_caret_height()
    local caret = Rectangle(self._content, Consts.CARET_WIDTH, height, Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self._caret = caret

    caret:set_origin(0, height * 0.5)
end

---@private
function TextInput:_center_text_vertically()
    local text = self._text_ctrl
    text:set_origin(0, text:get_font_height() * 0.5)
end

---@private
function TextInput:_create_text()
    local text = Text(self._content, "", Consts.TEXT_INPUT_FOREGROUND_COLOR, fonts.Kind.USER_INPUT)
    self._text_ctrl = text

    self:_center_text_vertically()
    text:set_scale(Consts.MENU_FIELD_SCALE)
end

---@private
function TextInput:_create_content()
    local content = Control(self._clip)
    self._content = content

    local _, height = self:get_size()
    content:set_position(0, height * 0.5)

    self:_create_selection()
    self:_create_caret()
    self:_create_text()
end

---@param parent Control
---@param form_screen FormScreen
---@param width number
---@param height number
---@param masked boolean|nil
---@param on_input InputHandler|nil Run after an edit
---@param on_enter InputHandler|nil Run on the return key
function TextInput:init(parent, form_screen, width, height, masked, on_input, on_enter)
    assert_type(form_screen, FormScreen)
    Control.init(self, parent, width, height)
    self._buffer = TextBuffer()
    Input.init(self, form_screen)
    self._padding = 10
    self._masked = masked or false
    self._on_input = on_input
    self._on_enter = on_enter
    self._caret_time = nil
    self._is_multivalue = false
    self._has_new_value = false
    self._offset = 0
    self._drag_id = nil
    self._press_time = nil
    self._clicks = 0
    local button = self:get_button()
    button.pointer_entered:register(self, self.on_pointer_entered)
    button.pointer_left:register(self, self.on_pointer_left)
    self._buffer.edited:register(self, self.on_edit)
    self._buffer.moved:register(self, self._update_view)
    self._buffer.removed_empty:register(self, self.on_remove_empty)
    self:_create_background()
    self:_create_clip()
    self:_create_content()
    self:_update_view()
end

function TextInput:on_screen_show()
    Input.on_screen_show(self)
    app.update_event:register(self, self.on_update)
    self:_set_pointer_events_registered(true)
    self:_update_text_events_registration()
end

function TextInput:on_screen_hide()
    app.update_event:unregister(self)
    self:_set_text_events_registered(false)
    self:_set_pointer_events_registered(false)
    Input.on_screen_hide(self)
end

---@param dt number
function TextInput:on_update(dt)
    local caret = self._caret
    if self:is_focused() then
        local time = self._caret_time + dt
        self._caret_time = time
        caret:set_enabled(math.fmod(time, Consts.CARET_BLINK_INTERVAL * 2) <= Consts.CARET_BLINK_INTERVAL)
    end
end

function TextInput:on_pointer_entered()
    _set_cursor("ibeam")
    self:_update_view()
end

function TextInput:on_pointer_left()
    _set_cursor("arrow")
    self:_update_view()
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function TextInput:on_pointer_down(x, y, id)
    if not _is_press(id) or self:is_read_only() then
        return true
    end
    self:get_form_screen():focus(self)
    local now = app:get_time()
    local clicks = 1
    if self._press_time and now - self._press_time <= Consts.MULTI_CLICK_INTERVAL then
        clicks = self._clicks % 3 + 1
    end
    self._press_time, self._clicks = now, clicks
    local buffer = self._buffer
    local index = self:_get_index_at(x, y)
    if clicks == 1 then
        buffer:set_caret(index, app.keyboard_manager:is_shift_down())
    elseif clicks == 2 then
        buffer:select_range(buffer:get_word_at(index))
    else
        buffer:select_all()
    end
    self._drag_id = id
    app.pointer_event_manager:capture(self, id)
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function TextInput:on_pointer_move(x, y, id)
    if self._drag_id == nil or id ~= self._drag_id then
        return true
    end
    self._buffer:set_caret(self:_get_index_at(x, y), true)
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function TextInput:on_pointer_up(x, y, id)
    if self._drag_id == nil or id ~= self._drag_id then
        return true
    end
    self._drag_id = nil
end

---@param text string
function TextInput:on_edit(text)
    if self._is_multivalue then
        self._has_new_value = true
    end
    self:_update_view()
    if self._on_input then
        self._on_input()
    end
end

function TextInput:on_enter()
    if self._on_enter then
        self._on_enter()
    end
    self:_update_view()
end

function TextInput:on_remove_empty()
    if self._is_multivalue then
        self._has_new_value = not self._has_new_value
    end
    self:_update_view()
end

---@param text string
function TextInput:on_append_text(text)
    self._buffer:insert(text)
end

---@private
---@return boolean Whether a selection went on the clipboard: there is one and the field is not masked
function TextInput:_copy()
    local buffer = self._buffer
    if self._masked or not buffer:has_selection() then
        return false
    end
    app.text_event_manager:set_clipboard(buffer:get_selected_text())
    return true
end

---@param command TextCommand
---@param direction TextDirection|nil
---@param step TextStep|nil
---@param extend boolean|nil
function TextInput:on_command(command, direction, step, extend)
    local buffer = self._buffer
    if command == Command.MOVE then
        buffer:move(assert(direction), assert(step), extend)
    elseif command == Command.DELETE then
        if self._masked and step == "word" then
            buffer:select_all()
        end
        buffer:delete(assert(direction), assert(step))
    elseif command == Command.SELECT_ALL then
        buffer:select_all()
    elseif command == Command.COPY then
        self:_copy()
    elseif command == Command.CUT then
        if self:_copy() then
            buffer:delete(-1, "character")
        end
    elseif command == Command.PASTE then
        local text = app.text_event_manager:get_clipboard()
        if text ~= "" then
            buffer:insert(text)
        end
    elseif command == Command.UNDO then
        buffer:undo()
    elseif command == Command.REDO then
        buffer:redo()
    elseif command == Command.ENTER then
        self:on_enter()
    end
end

function TextInput:on_focus()
    Input.on_focus(self)
    app.text_event_manager:set_text_input(true)
    self._buffer:select_all()
    self:_update_view()
end

function TextInput:on_focus_lost()
    Input.on_focus_lost(self)
    app.text_event_manager:set_text_input(false)
    if not lifetime.dying(self) then
        self._caret:set_enabled(false)
    end
    self:_update_view()
end

---@return string
function TextInput:get_text()
    return self._buffer:get_text()
end

---@return integer
function TextInput:get_text_length()
    return self._buffer:get_text_length()
end

---@return integer
function TextInput:get_caret()
    return self._buffer:get_caret()
end

---@return integer, integer The selection's start and end; equal when there is none
function TextInput:get_selection()
    return self._buffer:get_selection()
end

---@param text string
function TextInput:set_text(text)
    self._buffer:set_text(text)
    self:_update_view()
end

---@param filter TextFilter|nil Asked with the whole text every edit would produce; a false answer refuses the edit
function TextInput:set_filter(filter)
    self._buffer:set_filter(filter)
end

---@param face fonts.Face
function TextInput:set_font(face)
    self._text_ctrl:set_font(face)
    self:_center_text_vertically()
    self:_update_view()
end

---@param value boolean
function TextInput:set_multivalue(value)
    if value then
        self._buffer:set_text("")
    end
    self._is_multivalue = value
    self._has_new_value = false
    self:_update_view()
end

---@return boolean
function TextInput:is_multivalue()
    return self._is_multivalue
end

---@return boolean
function TextInput:is_multivalue_default()
    return self._is_multivalue and not self._has_new_value
end

function TextInput:on_read_only_change()
    Input.on_read_only_change(self)
    self:_update_view()
end

return TextInput

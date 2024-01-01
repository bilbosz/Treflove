local ButtonEventListener = require("ui.button-event").Listener
local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Control = require("controls.control")
local FormScreen = require("ui.form-screen")
local Input = require("ui.input")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")
local TextEventListener = require("ui.text-event").Listener
local UpdateEventListener = require("events.update-event").Listener

---@class TextInput: Control, UpdateEventListener, ButtonEventListener, TextEventListener, Input
---@field private _background Rectangle
---@field private _caret Rectangle
---@field private _caret_time number
---@field private _clip ClippingRectangle
---@field private _content Control
---@field private _has_new_value boolean
---@field private _is_multivalue boolean
---@field private _masked boolean
---@field private _on_enter fun():void
---@field private _on_input fun():void
---@field private _padding number
---@field private _text_ctrl Text
local TextInput = class("TextInput", Control, UpdateEventListener, ButtonEventListener, TextEventListener, Input)

---@private
---@return void
function TextInput:_upload_background_view()
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
---@return void
function TextInput:_update_text_view()
    local text = self._text_ctrl
    if self._masked then
        text:set_text(string.rep("•", self:get_text_length()))
    else
        text:set_text(self:get_text())
    end
end

---@private
---@return void
function TextInput:_upload_caret_view()
    local caret = self._caret
    local is_focused = self:is_focused()
    caret:set_enabled(is_focused)
    if is_focused then
        self._caret_time = 0
    end

    local text = self._text_ctrl
    local w = text:get_size() * text:get_scale()
    caret:set_position(w)
end

---@private
---@return void
function TextInput:_update_content_view()
    self:_update_text_view()
    self:_upload_caret_view()

    local content = self._content
    local w = content:get_recursive_aabb():get_width()
    if w > self._clip:get_size() then
        content:set_origin(w, nil)
        content:set_position(self._clip:get_size(), nil)
    else
        content:set_origin(0, nil)
        content:set_position(0, nil)
    end
end

---@private
---@return void
function TextInput:_update_view()
    self:_upload_background_view()
    self:_update_content_view()

    if self:is_focused() then
        app.text_event_manager:register_listener(self)
    else
        app.text_event_manager:unregister_listener(self)
    end
end

---@private
---@return void
function TextInput:_create_background()
    local width, height = self:get_size()
    self._background = Rectangle(self, width, height, Consts.BUTTON_NORMAL_COLOR)
end

---@private
---@return void
function TextInput:_create_clip()
    local width, height = self:get_size()
    local clip = ClippingRectangle(self, width - 2 * self._padding, height)
    self._clip = clip

    clip:set_position(self._padding, 0)
end

---@private
---@return void
function TextInput:_create_caret()
    local _, height = self:get_size()
    local caret_height = height - 2 * self._padding
    local caret = Rectangle(self._content, Consts.CARET_WIDTH, caret_height, Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self._caret = caret

    caret:set_origin(0, caret_height * 0.5)
end

---@private
---@return void
function TextInput:_create_text()
    local font = Consts.USER_INPUT_FONT
    local text = Text(self._content, "", Consts.TEXT_INPUT_FOREGROUND_COLOR, font)
    self._text_ctrl = text

    text:set_origin(0, font:getHeight() * 0.5)
    text:set_scale(Consts.MENU_FIELD_SCALE)
end

---@private
---@return void
function TextInput:_create_content()
    local content = Control(self._clip)
    self._content = content

    local _, height = self:get_size()
    content:set_position(0, height * 0.5)

    self:_create_caret()
    self:_create_text()
end

---@param parent Control
---@param form_screen FormScreen
---@param width number
---@param height number
---@param masked boolean
---@param on_input fun():void
---@param on_enter fun():void
---@return void
function TextInput:init(parent, form_screen, width, height, masked, on_input, on_enter)
    assert_type(form_screen, FormScreen)
    Control.init(self, parent, width, height)
    ButtonEventListener.init(self)
    TextEventListener.init(self)
    Input.init(self, form_screen)
    self._padding = 10
    self._masked = masked or false
    self._on_input = on_input
    self._on_enter = on_enter
    self._caret_time = nil
    self._is_multivalue = false
    self._has_new_value = false
    self:_create_background()
    self:_create_clip()
    self:_create_content()
    self:_update_view()
end

---@return void
function TextInput:on_screen_show()
    Input.on_screen_show(self)
    app.update_event_manager:register_listener(self)
end

---@return void
function TextInput:on_screen_hide()
    app.update_event_manager:unregister_listener(self)
    app.text_event_manager:unregister_listener(self)
    Input.on_screen_hide(self)
end

---@param dt number
---@return void
function TextInput:on_update(dt)
    local caret = self._caret
    if self:is_focused() then
        local time = self._caret_time + dt
        self._caret_time = time
        caret:set_enabled(math.fmod(time, Consts.CARET_BLINK_INTERVAL * 2) <= Consts.CARET_BLINK_INTERVAL)
    end
end

---@return void
function TextInput:on_pointer_enter()
    ButtonEventListener.on_pointer_enter(self)
    self:_update_view()
end

---@return void
function TextInput:on_pointer_leave()
    ButtonEventListener.on_pointer_leave(self)
    self:_update_view()
end

---@return void
function TextInput:on_click()
    ButtonEventListener.on_click(self)
    self:get_form_screen():focus(self)
    self:_update_view()
end

---@param ... vararg
---@return void
function TextInput:on_edit(...)
    if self._is_multivalue then
        self._has_new_value = true
    end
    self:_update_view()
    if self._on_input then
        self._on_input()
    end
end

---@return void
function TextInput:on_enter()
    if self._on_enter then
        self._on_enter()
    end
    self:_update_view()
end

---@return void
function TextInput:on_remove_empty()
    if self._is_multivalue then
        self._has_new_value = not self._has_new_value
    end
    self:_update_view()
end

---@return void
function TextInput:on_remove_word()
    if self._masked then
        self:set_text("")
    else
        TextEventListener.on_remove_word(self)
    end
end

---@return void
function TextInput:on_focus()
    Input.on_focus(self)
    app.text_event_manager:set_text_input(true)
    self:_update_view()
end

---@return void
function TextInput:on_focus_lost()
    Input.on_focus_lost(self)
    app.text_event_manager:set_text_input(false)
    self._caret:set_enabled(false)
    self:_update_view()
end

---@param text string
---@return void
function TextInput:set_text(text)
    TextEventListener.set_text(self, text)
    self:_update_view()
end

---@param value boolean
---@return void
function TextInput:set_multivalue(value)
    if value then
        TextEventListener.set_text(self, "")
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

---@return void
function TextInput:on_read_only_change()
    Input.on_read_only_change(self)
    self:_update_view()
end

return TextInput

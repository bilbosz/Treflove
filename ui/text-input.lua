local Control = require("controls.control")
local UpdateEventListener = require("events.update-event").Listener
local ButtonEventListener = require("ui.button-event").Listener
local TextEventListener = require("ui.text-event").Listener
local Input = require("ui.input")
local Consts = require("app.consts")
local Rectangle = require("controls.rectangle")
local ClippingRectangle = require("controls.clipping-rectangle")
local Text = require("controls.text")
local FormScreen = require("ui.form-screen")

---@class TextInput: Control, UpdateEventListener, ButtonEventListener, TextEventListener, Input
local TextInput = class("TextInput", Control, UpdateEventListener, ButtonEventListener, TextEventListener, Input)

local function _upload_background_view(self)
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
    self.background:set_color(color)
end

local function _update_text_view(self)
    local text = self.text_ctrl
    if self.masked then
        text:set_text(string.rep("•", self:get_text_length()))
    else
        text:set_text(self:get_text())
    end
end

local function _upload_caret_view(self)
    local caret = self.caret
    local is_focused = self:is_focused()
    caret:set_enabled(is_focused)
    if is_focused then
        self.caret_time = 0
    end

    local text = self.text_ctrl
    local w = text:get_size() * text:get_scale()
    caret:set_position(w)
end

local function _update_content_view(self)
    _update_text_view(self)
    _upload_caret_view(self)

    local content = self.content
    local w = content:get_recursive_aabb():get_width()
    if w > self.clip:get_size() then
        content:set_origin(w, nil)
        content:set_position(self.clip:get_size(), nil)
    else
        content:set_origin(0, nil)
        content:set_position(0, nil)
    end
end

local function _update_view(self)
    _upload_background_view(self)
    _update_content_view(self)

    if self:is_focused() then
        app.text_event_manager:register_listener(self)
    else
        app.text_event_manager:unregister_listener(self)
    end
end

local function _create_background(self)
    self.background = Rectangle(self, self.width, self.height, Consts.BUTTON_NORMAL_COLOR)
end

local function _create_clip(self)
    local clip = ClippingRectangle(self, self.width - 2 * self.padding, self.height)
    self.clip = clip

    clip:set_position(self.padding, 0)
end

local function _create_caret(self)
    local h = self.height - 2 * self.padding
    local caret = Rectangle(self.content, Consts.CARET_WIDTH, h, Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self.caret = caret

    caret:set_origin(0, h * 0.5)
end

local function _create_text(self)
    local font = Consts.USER_INPUT_FONT
    local text = Text(self.content, "", Consts.TEXT_INPUT_FOREGROUND_COLOR, font)
    self.text_ctrl = text

    text:set_origin(0, font:getHeight() * 0.5)
    text:set_scale(Consts.MENU_FIELD_SCALE)
end

local function _create_content(self)
    local content = Control(self.clip)
    self.content = content

    content:set_position(0, self.height * 0.5)

    _create_caret(self)
    _create_text(self)
end

function TextInput:init(parent, form_screen, width, height, masked, on_input, on_enter)
    assert_type(form_screen, FormScreen)
    Control.init(self, parent, width, height)
    ButtonEventListener.init(self)
    TextEventListener.init(self)
    Input.init(self, form_screen)
    self.width = width
    self.height = height
    self.padding = 10
    self.masked = masked or false
    self.on_input = on_input
    self.on_enter = on_enter
    self.caret_time = nil
    self.is_multivalue = false
    self.has_new_value = false
    _create_background(self)
    _create_clip(self)
    _create_content(self)
    _update_view(self)
end

function TextInput:on_screen_show()
    Input.on_screen_show(self)
    app.update_event_manager:register_listener(self)
end

function TextInput:on_screen_hide()
    app.update_event_manager:unregister_listener(self)
    app.text_event_manager:unregister_listener(self)
    Input.on_screen_hide(self)
end

function TextInput:on_update(dt)
    local caret = self.caret
    if self:is_focused() then
        local time = self.caret_time + dt
        self.caret_time = time
        caret:set_enabled(math.fmod(time, Consts.CARET_BLINK_INTERVAL * 2) <= Consts.CARET_BLINK_INTERVAL)
    end
end

function TextInput:on_pointer_enter()
    ButtonEventListener.on_pointer_enter(self)
    _update_view(self)
end

function TextInput:on_pointer_leave()
    ButtonEventListener.on_pointer_leave(self)
    _update_view(self)
end

function TextInput:on_click()
    ButtonEventListener.on_click(self)
    self:get_form_screen():focus(self)
    _update_view(self)
end

function TextInput:on_edit(...)
    if self.is_multivalue then
        self.has_new_value = true
    end
    _update_view(self)
    if self.on_input then
        self.on_input()
    end
end

function TextInput:on_enter()
    if self.on_enter then
        self.on_enter()
    end
    _update_view(self)
end

function TextInput:on_remove_empty()
    if self.is_multivalue then
        self.has_new_value = not self.has_new_value
    end
    _update_view(self)
end

function TextInput:on_remove_word()
    if self.masked then
        self:set_text("")
    else
        TextEventListener.on_remove_word(self)
    end
end

function TextInput:on_focus()
    Input.on_focus(self)
    app.text_event_manager:set_text_input(true)
    _update_view(self)
end

function TextInput:on_focus_lost()
    Input.on_focus_lost(self)
    app.text_event_manager:set_text_input(false)
    self.caret:set_enabled(false)
    _update_view(self)
end

function TextInput:set_text(text)
    TextEventListener.set_text(self, text)
    _update_view(self)
end

function TextInput:set_multivalue(value)
    if value then
        TextEventListener.set_text(self, "")
    end
    self.is_multivalue = value
    self.has_new_value = false
    _update_view(self)
end

function TextInput:is_multivalue()
    return self.is_multivalue
end

function TextInput:is_multivalue_default()
    return self.is_multivalue and not self.has_new_value
end

function TextInput:on_read_only_change()
    Input.on_read_only_change(self)
    _update_view(self)
end

return TextInput

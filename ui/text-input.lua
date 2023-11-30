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

local function UpdateBackgroundView(self)
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

local function UpdateTextView(self)
    local text = self.textCtrl
    if self.masked then
        text:set_text(string.rep("•", self:get_text_length()))
    else
        text:set_text(self:get_text())
    end
end

local function UpdateCaretView(self)
    local caret = self.caret
    local isFocused = self:is_focused()
    caret:set_enabled(isFocused)
    if isFocused then
        self.caretTime = 0
    end

    local text = self.textCtrl
    local w = text:get_size() * text:get_scale()
    caret:set_position(w)
end

local function UpdateContentView(self)
    UpdateTextView(self)
    UpdateCaretView(self)

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

local function UpdateView(self)
    UpdateBackgroundView(self)
    UpdateContentView(self)

    if self:is_focused() then
        app.text_event_manager:register_listener(self)
    else
        app.text_event_manager:unregister_listener(self)
    end
end

local function CreateBackground(self)
    self.background = Rectangle(self, self.width, self.height, Consts.BUTTON_NORMAL_COLOR)
end

local function CreateClip(self)
    local clip = ClippingRectangle(self, self.width - 2 * self.padding, self.height)
    self.clip = clip

    clip:set_position(self.padding, 0)
end

local function CreateCaret(self)
    local h = self.height - 2 * self.padding
    local caret = Rectangle(self.content, Consts.CARET_WIDTH, h, Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self.caret = caret

    caret:set_origin(0, h * 0.5)
end

local function CreateText(self)
    local font = Consts.USER_INPUT_FONT
    local text = Text(self.content, "", Consts.TEXT_INPUT_FOREGROUND_COLOR, font)
    self.textCtrl = text

    text:set_origin(0, font:getHeight() * 0.5)
    text:set_scale(Consts.MENU_FIELD_SCALE)
end

local function CreateContent(self)
    local content = Control(self.clip)
    self.content = content

    content:set_position(0, self.height * 0.5)

    CreateCaret(self)
    CreateText(self)
end

function TextInput:init(parent, formScreen, width, height, masked, onInput, onEnter)
    assert_type(formScreen, FormScreen)
    Control.init(self, parent, width, height)
    ButtonEventListener.init(self)
    TextEventListener.init(self)
    Input.init(self, formScreen)
    self.width = width
    self.height = height
    self.padding = 10
    self.masked = masked or false
    self.onInput = onInput
    self.onEnter = onEnter
    self.caretTime = nil
    self.isMultivalue = false
    self.hasNewValue = false
    CreateBackground(self)
    CreateClip(self)
    CreateContent(self)
    UpdateView(self)
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
        local time = self.caretTime + dt
        self.caretTime = time
        caret:set_enabled(math.fmod(time, Consts.CARET_BLINK_INTERVAL * 2) <= Consts.CARET_BLINK_INTERVAL)
    end
end

function TextInput:on_pointer_enter()
    ButtonEventListener.on_pointer_enter(self)
    UpdateView(self)
end

function TextInput:on_pointer_leave()
    ButtonEventListener.on_pointer_leave(self)
    UpdateView(self)
end

function TextInput:on_click()
    ButtonEventListener.on_click(self)
    self:get_form_screen():focus(self)
    UpdateView(self)
end

function TextInput:on_edit(...)
    if self.isMultivalue then
        self.hasNewValue = true
    end
    UpdateView(self)
    if self.onInput then
        self.onInput()
    end
end

function TextInput:on_enter()
    if self.onEnter then
        self.onEnter()
    end
    UpdateView(self)
end

function TextInput:on_remove_empty()
    if self.isMultivalue then
        self.hasNewValue = not self.hasNewValue
    end
    UpdateView(self)
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
    UpdateView(self)
end

function TextInput:on_focus_lost()
    Input.on_focus_lost(self)
    app.text_event_manager:set_text_input(false)
    self.caret:set_enabled(false)
    UpdateView(self)
end

function TextInput:set_text(text)
    TextEventListener.set_text(self, text)
    UpdateView(self)
end

function TextInput:set_multivalue(value)
    if value then
        TextEventListener.set_text(self, "")
    end
    self.isMultivalue = value
    self.hasNewValue = false
    UpdateView(self)
end

function TextInput:is_multivalue()
    return self.isMultivalue
end

function TextInput:is_multivalue_default()
    return self.isMultivalue and not self.hasNewValue
end

function TextInput:on_read_only_change()
    Input.on_read_only_change(self)
    UpdateView(self)
end

return TextInput

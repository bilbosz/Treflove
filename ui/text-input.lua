local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Control = require("controls.control")
local fonts = require("graphics.fonts")
local FormScreen = require("ui.form-screen")
local Input = require("ui.input")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")
local TextBuffer = require("ui.text-buffer")
local lifetime = require("lifetime")

---@class TextInput: Control, Input
---@field private _background Rectangle
---@field private _buffer TextBuffer
---@field private _caret Rectangle
---@field private _caret_time number|nil
---@field private _clip ClippingRectangle
---@field private _content Control
---@field private _has_new_value boolean
---@field private _is_multivalue boolean
---@field private _masked boolean
---@field private _on_enter InputHandler|nil
---@field private _on_input InputHandler|nil
---@field private _padding number
---@field private _text_ctrl Text
local TextInput = class("TextInput", Control, Input)

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
function TextInput:_update_text_view()
    local text = self._text_ctrl
    if self._masked then
        text:set_text(string.rep("•", self:get_text_length()))
    else
        text:set_text(self:get_text())
    end
end

---@private
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
        manager.characters_removed:register(self, self.on_remove_characters)
        manager.word_removed:register(self, self.on_remove_word)
        manager.entered:register(self, self.on_enter)
    else
        manager.text_appended:unregister(self)
        manager.characters_removed:unregister(self)
        manager.word_removed:unregister(self)
        manager.entered:unregister(self)
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
function TextInput:_create_caret()
    local _, height = self:get_size()
    local caret_height = height - 2 * self._padding
    local caret = Rectangle(self._content, Consts.CARET_WIDTH, caret_height, Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self._caret = caret

    caret:set_origin(0, caret_height * 0.5)
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
    local button = self:get_button()
    button.pointer_entered:register(self, self._update_view)
    button.pointer_left:register(self, self._update_view)
    button.clicked:register(self, self.on_click)
    self._buffer.edited:register(self, self.on_edit)
    self._buffer.removed_empty:register(self, self.on_remove_empty)
    self:_create_background()
    self:_create_clip()
    self:_create_content()
    self:_update_view()
end

function TextInput:on_screen_show()
    Input.on_screen_show(self)
    app.update_event:register(self, self.on_update)
    self:_update_text_events_registration()
end

function TextInput:on_screen_hide()
    app.update_event:unregister(self)
    self:_set_text_events_registered(false)
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

function TextInput:on_click()
    self:get_form_screen():focus(self)
    self:_update_view()
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
    self._buffer:append_text(text)
end

---@param character_number number
function TextInput:on_remove_characters(character_number)
    self._buffer:remove_characters(character_number)
end

function TextInput:on_remove_word()
    if self._masked then
        self:set_text("")
    else
        self._buffer:remove_word()
    end
end

function TextInput:on_focus()
    Input.on_focus(self)
    app.text_event_manager:set_text_input(true)
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

---@param text string
function TextInput:set_text(text)
    self._buffer:set_text(text)
    self:_update_view()
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

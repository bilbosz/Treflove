local Button = require("ui.button")
local FormScreen = require("ui.form-screen")

---Interface for focusable form elements. Not a Control subclass at runtime,
---but always mixed into Control-derived classes (see TextInput, TextButton),
---which the `: Control` annotation reflects.
---
---Every input is clickable: it owns a `Button` (hover/selection state and
---pointer events) that is registered with `app.button_event_manager` while the
---form screen is shown. Subclasses register their methods on its events, e.g.
---`self:get_button().clicked:register(self, self.on_click)`.
---@class Input: Control
---@field private _button Button
---@field private _form_screen FormScreen
---@field private _is_focused boolean
---@field private _is_read_only boolean
local Input = class("Input")

---@param form_screen FormScreen
function Input:init(form_screen)
    assert_type(form_screen, FormScreen)
    self._button = Button()
    self._form_screen = form_screen
    self._is_focused = false
    self._is_read_only = false
    form_screen:add_input(self)
    if form_screen:is_showed() then
        self:on_screen_show()
    end
end

---@return Button
function Input:get_button()
    return self._button
end

---@return boolean
function Input:is_hovered()
    return self._button:is_hovered()
end

---@return boolean
function Input:is_selected()
    return self._button:is_selected()
end

---@return FormScreen
function Input:get_form_screen()
    return self._form_screen
end

---@param value boolean
function Input:set_read_only(value)
    if self._is_read_only ~= value then
        self._is_read_only = value
        self:on_read_only_change()
    end
end

---@return boolean
function Input:is_read_only()
    return self._is_read_only
end

function Input:on_read_only_change()
    self._form_screen:read_only_change(self)
end

function Input:on_screen_show()
    app.button_event_manager:register(self, self._button)
end

function Input:on_screen_hide()
    app.button_event_manager:unregister(self)
end

function Input:on_focus()
    self._is_focused = true
end

function Input:on_focus_lost()
    self._is_focused = false
end

---@return boolean
function Input:is_focused()
    return self._is_focused
end

return Input

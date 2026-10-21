local Button = require("ui.button")
local FormScreen = require("ui.form-screen")
local lifetime = require("lifetime")

---@alias InputHandler fun() Run by an input on a user action: an edit, the return key, a click

---Not a Control subclass at runtime, always mixed into one: what the
---`: Control` annotation reflects.
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
    lifetime.hook(function(reason)
        -- A form holds its inputs, so one the collector finds is garbage with
        -- its form, which may be a tombstone already or die in a finalizer
        -- nested at an allocation inside a call made into it: nothing to
        -- unlink then (docs/lifetimes.md, "Forms and inputs")
        if reason == "unreachable" or reason == "exit" then
            return
        end
        if lifetime.alive(form_screen) and not lifetime.dying(form_screen) then
            form_screen:remove_input(self)
        end
        -- a button kept under the pointer or pressed would be driven later
        app.button_event_manager:unregister(self)
    end, form_screen, self)
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

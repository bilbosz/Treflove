local FormScreen = require("ui.form-screen")

---@class Input
---@field private _form_screen FormScreen
---@field private _is_focused boolean
---@field private _is_read_only boolean
local Input = class("Input")

---@param form_screen FormScreen
---@return void
function Input:init(form_screen)
    assert_type(form_screen, FormScreen)
    self._form_screen = form_screen
    self._is_focused = false
    self._is_read_only = false
    form_screen:add_input(self)
    if form_screen:is_showed() then
        self:on_screen_show()
    end
end

---@return FormScreen
function Input:get_form_screen()
    return self._form_screen
end

---@param value boolean
---@return void
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

---@return void
function Input:on_read_only_change()
    self._form_screen:read_only_change(self)
end

---@return void
function Input:on_screen_show()
    app.button_event_manager:register_listener(self)
end

---@return void
function Input:on_screen_hide()
    app.button_event_manager:unregister_listener(self)
end

---@return void
function Input:on_focus()
    self._is_focused = true
end

---@return void
function Input:on_focus_lost()
    self._is_focused = false
end

---@return boolean
function Input:is_focused()
    return self._is_focused
end

return Input

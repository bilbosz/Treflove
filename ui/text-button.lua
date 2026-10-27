local Consts = require("app.consts")
local Input = require("ui.input")
local Text = require("controls.text")

---@class TextButton: Text, Input
---@field private _action InputHandler
---@field private _is_active boolean Shown in the active (blueish) colors: what the button stands for is on
local TextButton = class("TextButton", Text, Input)

---@private
function TextButton:_update_text_color()
    local active = self._is_active
    ---@type number[]
    local color
    if self:is_read_only() then
        color = Consts.BUTTON_READ_ONLY_COLOR
    elseif self:is_focused() or self:is_selected() then
        color = active and Consts.BUTTON_ACTIVE_SELECT_COLOR or Consts.BUTTON_SELECT_COLOR
    elseif self:is_hovered() then
        color = active and Consts.BUTTON_ACTIVE_HOVER_COLOR or Consts.BUTTON_HOVER_COLOR
    else
        color = active and Consts.BUTTON_ACTIVE_COLOR or Consts.BUTTON_NORMAL_COLOR
    end
    self:set_color(color)
end

---@param parent Control
---@param form_screen FormScreen
---@param text string
---@param action InputHandler Run on a click or the return key
function TextButton:init(parent, form_screen, text, action)
    Text.init(self, parent, text, Consts.BUTTON_NORMAL_COLOR)
    Input.init(self, form_screen)
    self._action = action
    self._is_active = false
    local button = self:get_button()
    button.selected:register(self, self._update_text_color)
    button.unselected:register(self, self._update_text_color)
    button.pointer_entered:register(self, self._update_text_color)
    button.pointer_left:register(self, self._update_text_color)
    button.clicked:register(self, self.on_click)
end

function TextButton:on_screen_show()
    Input.on_screen_show(self)
    if self:is_focused() then
        app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
    end
end

function TextButton:on_screen_hide()
    Input.on_screen_hide(self)
    app.keyboard_manager.key_pressed:unregister(self)
end

function TextButton:on_focus()
    Input.on_focus(self)
    self:_update_text_color()
    app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
end

function TextButton:on_focus_lost()
    app.keyboard_manager.key_pressed:unregister(self)
    Input.on_focus_lost(self)
    self:_update_text_color()
end

function TextButton:on_click()
    self._action()
end

---@param value boolean
function TextButton:set_active(value)
    if self._is_active ~= value then
        self._is_active = value
        self:_update_text_color()
    end
end

---@return boolean
function TextButton:is_active()
    return self._is_active
end

function TextButton:on_read_only_change()
    Input.on_read_only_change(self)
    self:_update_text_color()
end

---@param key love.KeyConstant
function TextButton:on_key_pressed(key)
    if key == "return" then
        self._action()
    end
end

return TextButton

local Text = require("controls.text")
local ButtonEventListener = require("ui.button-event").Listener
local Input = require("ui.input")
local KeyboardEventListener = require("events.keyboard").Listener
local Consts = require("app.consts")

---@class TextButton: Text, ButtonEventListener, Input, KeyboardEventListener
local TextButton = class("TextButton", Text, ButtonEventListener, Input, KeyboardEventListener)

local function UpdateTextColor(self)
    self:set_color((self:is_focused() or self:is_selected()) and Consts.BUTTON_SELECT_COLOR or self:is_hovered() and Consts.BUTTON_HOVER_COLOR or Consts.BUTTON_NORMAL_COLOR)
end

function TextButton:init(parent, form_screen, text, action)
    Text.init(self, parent, text, Consts.BUTTON_NORMAL_COLOR)
    ButtonEventListener.init(self)
    Input.init(self, form_screen)
    KeyboardEventListener.init(self, true)
    self.action = action
    self.is_hover = false
    self.text = text
end

function TextButton:on_screen_show()
    Input.on_screen_show(self)
    if self:is_focused() then
        app.keyboard_manager:register_listener(self)
    end
end

function TextButton:on_screen_hide()
    Input.on_screen_hide(self)
    app.keyboard_manager:unregister_listener(self)
end

function TextButton:on_focus()
    Input.on_focus(self)
    UpdateTextColor(self)
    app.keyboard_manager:register_listener(self)
end

function TextButton:on_focus_lost()
    app.keyboard_manager:unregister_listener(self)
    Input.on_focus_lost(self)
    UpdateTextColor(self)
end

function TextButton:on_select()
    ButtonEventListener.on_select(self)
    UpdateTextColor(self)
end

function TextButton:on_unselect()
    ButtonEventListener.on_unselect(self)
    UpdateTextColor(self)
end

function TextButton:on_pointer_enter()
    ButtonEventListener.on_pointer_enter(self)
    UpdateTextColor(self)
end

function TextButton:on_pointer_leave()
    ButtonEventListener.on_pointer_leave(self)
    UpdateTextColor(self)
end

function TextButton:on_click()
    ButtonEventListener.on_click(self)
    self.action()
end

function TextButton:on_key_pressed(key)
    if key == "return" then
        self.action()
    end
end

return TextButton

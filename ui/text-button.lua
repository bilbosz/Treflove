local ButtonEventListener = require("ui.button-event").Listener
local Consts = require("app.consts")
local Input = require("ui.input")
local KeyboardEventListener = require("events.keyboard").Listener
local Text = require("controls.text")

---@class TextButton: Text, ButtonEventListener, Input, KeyboardEventListener
---@field private _action fun():void
local TextButton = class("TextButton", Text, ButtonEventListener, Input, KeyboardEventListener)

---@private
function TextButton:_update_text_color()
    self:set_color((self:is_focused() or self:is_selected()) and Consts.BUTTON_SELECT_COLOR or self:is_hovered() and Consts.BUTTON_HOVER_COLOR or Consts.BUTTON_NORMAL_COLOR)
end

---@param parent Control
---@param form_screen FormScreen
---@param text string
---@param action fun():void
function TextButton:init(parent, form_screen, text, action)
    Text.init(self, parent, text, Consts.BUTTON_NORMAL_COLOR)
    ButtonEventListener.init(self)
    Input.init(self, form_screen)
    KeyboardEventListener.init(self, true)
    self._action = action
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
    self:_update_text_color()
    app.keyboard_manager:register_listener(self)
end

function TextButton:on_focus_lost()
    app.keyboard_manager:unregister_listener(self)
    Input.on_focus_lost(self)
    self:_update_text_color()
end

function TextButton:on_select()
    ButtonEventListener.on_select(self)
    self:_update_text_color()
end

function TextButton:on_unselect()
    ButtonEventListener.on_unselect(self)
    self:_update_text_color()
end

function TextButton:on_pointer_enter()
    ButtonEventListener.on_pointer_enter(self)
    self:_update_text_color()
end

function TextButton:on_pointer_leave()
    ButtonEventListener.on_pointer_leave(self)
    self:_update_text_color()
end

function TextButton:on_click()
    ButtonEventListener.on_click(self)
    self._action()
end

function TextButton:on_key_pressed(key)
    if key == "return" then
        self._action()
    end
end

return TextButton

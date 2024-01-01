local KeyboardEventListener = require("events.keyboard").Listener
local Screen = require("screens.screen")

---@class FormScreen: Screen, KeyboardEventListener
---@field private _focus number
---@field private _inputs Input[]
---@field private _is_showed boolean
---@field private _prev_focus number
local FormScreen = class("FormScreen", Screen, KeyboardEventListener)

---@private
---@return void
function FormScreen:_notify_listeners()
    if self.prev_focus == self._focus then
        return
    end
    local old_item = self._inputs[self.prev_focus]
    if old_item then
        old_item:on_focus_lost()
    end
    local new_item = self._inputs[self._focus]
    if new_item then
        new_item:on_focus()
    end
end

---@private
---@param d number
---@return void
function FormScreen:_advance_focus(d)
    assert(d == 1 or d == -1)
    local inputs = self._inputs
    self.prev_focus = self._focus

    local n = #inputs
    if n == 0 then
        return
    end

    local count = 0
    for _, v in ipairs(inputs) do
        if not v:is_read_only() then
            count = count + 1
        end
    end
    if count == 0 then
        return
    end

    local i = self._focus or 0
    while true do
        i = (i + d - 1 + n) % n + 1
        if inputs[i]:are_all_predecessors_enabled() and not inputs[i]:is_read_only() then
            break
        end
    end
    self._focus = i
end

---@return void
function FormScreen:init()
    Screen.init(self)
    KeyboardEventListener.init(self, true)
    self._inputs = {}
    self._prev_focus = nil
    self._focus = nil
    self._is_showed = false
end

---@param ... vararg
---@return void
function FormScreen:show(...)
    Screen.show(self, ...)
    for _, input in ipairs(self._inputs) do
        input:on_screen_show()
    end
    app.keyboard_manager:register_listener(self)
    self._is_showed = true
end

---@return void
function FormScreen:hide()
    self._is_showed = false
    app.keyboard_manager:unregister_listener(self)
    for _, input in ipairs(self._inputs) do
        input:on_screen_hide()
    end
    Screen.hide(self)
end

---@return boolean
function FormScreen:is_showed()
    return self._is_showed
end

---@param key string
---@return void
function FormScreen:on_key_pressed(key)
    if key == "tab" then
        if app.keyboard_manager:is_key_down("lshift") then
            self:_advance_focus(-1)
        else
            self:_advance_focus( 1)
        end
        self:_notify_listeners()
    end
end

---@param input Input
---@return void
function FormScreen:add_input(input)
    table.insert(self._inputs, input)
end

---@param input Input
---@return void
function FormScreen:remove_input(input)
    local found = table.find_array_idx(self._inputs, input)
    assert(found)
    table.remove(self._inputs, found)
    if found == self._focus then
        self._focus = nil
    end
    if found == self._prev_focus then
        self._prev_focus = nil
    end
end

---@param input Input
---@return void
function FormScreen:read_only_change(input)
    local found = table.find_array_idx(self._inputs, input)
    assert(found)
    if found == self._focus then
        self:_advance_focus(1)
    end
end

---@param input Input
---@return void
function FormScreen:focus(input)
    local found
    for i, v in ipairs(self._inputs) do
        if v == input then
            found = i
            break
        end
    end
    assert(found)
    self._prev_focus = self._focus
    self._focus = found
    self:_notify_listeners()
end

---@return void
function FormScreen:remove_all_inputs()
    self._inputs = {}
    self._prev_focus = nil
    self._focus = nil
end

return FormScreen

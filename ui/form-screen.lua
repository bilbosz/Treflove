local Screen = require("screens.screen")

---@class FormScreen: Screen
---@field private _focus number
---@field private _inputs Input[]
---@field private _is_showed boolean
---@field private _is_released boolean lua-lifetime: set by the destructor, read by the inputs' hooks
---@field private _prev_focus number
local FormScreen = class("FormScreen", Screen)

---@private
function FormScreen:_notify_listeners()
    if self._prev_focus == self._focus then
        return
    end
    local old_item = self._inputs[self._prev_focus]
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
function FormScreen:_advance_focus(d)
    assert(d == 1 or d == -1)
    local inputs = self._inputs
    self._prev_focus = self._focus

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

function FormScreen:init()
    Screen.init(self)
    self._inputs = {}
    self._prev_focus = nil
    self._focus = nil
    self._is_showed = false
    self._is_released = false
end

---@param ... any Arguments forwarded to `Screen.show`
function FormScreen:show(...)
    Screen.show(self, ...)
    -- set before notifying the inputs, so they see the screen as shown (`hide` clears it first)
    self._is_showed = true
    for _, input in ipairs(self._inputs) do
        input:on_screen_show()
    end
    app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
end

function FormScreen:hide()
    self._is_showed = false
    app.keyboard_manager.key_pressed:unregister(self)
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
function FormScreen:on_key_pressed(key)
    if key == "tab" then
        if app.keyboard_manager:is_key_down("lshift") then
            self:_advance_focus(-1)
        else
            self:_advance_focus(1)
        end
        self:_notify_listeners()
    end
end

---@param input Input
function FormScreen:add_input(input)
    table.insert(self._inputs, input)
end

---@param input Input
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
function FormScreen:read_only_change(input)
    local found = table.find_array_idx(self._inputs, input)
    assert(found)
    if found == self._focus then
        self:_advance_focus(1)
    end
end

---@param input Input
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

function FormScreen:remove_all_inputs()
    self._inputs = {}
    self._prev_focus = nil
    self._focus = nil
end

---lua-lifetime: the destructor runs before the hooks of the inputs
---(lib/lua-lifetime/docs/02-semantics.md, "Cascading death"), so this flag
---tells each input's hook that the form went first (ui/input.lua).
---@param reason lifetime.Reason
function FormScreen:release(reason)
    self._is_released = true
    Screen.release(self, reason)
end

---@return boolean
function FormScreen:is_released()
    return self._is_released
end

return FormScreen

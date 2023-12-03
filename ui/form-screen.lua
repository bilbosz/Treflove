local Screen = require("screens.screen")
local KeyboardEventListener = require("events.keyboard").Listener
-- local Input = require("ui.input")

---@class FormScreen: Screen, KeyboardEventListener
local FormScreen = class("FormScreen", Screen, KeyboardEventListener)

local function _notify_listeners(self)
    if self.prev_focus == self._focus then
        return
    end
    local old_item = self.inputs[self.prev_focus]
    if old_item then
        old_item:on_focus_lost()
    end
    local new_item = self.inputs[self._focus]
    if new_item then
        new_item:on_focus()
    end
end

local function _advance_focus(self, d)
    assert(d == 1 or d == -1)
    local inputs = self.inputs
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

function FormScreen:init()
    Screen.init(self)
    KeyboardEventListener.init(self, true)
    self.inputs = {}
    self.prev_focus = nil
    self._focus = nil
    self._is_showed = false
end

function FormScreen:show(...)
    Screen.show(self, ...)
    for _, input in ipairs(self.inputs) do
        input:on_screen_show()
    end
    app.keyboard_manager:register_listener(self)
    self._is_showed = true
end

function FormScreen:hide()
    self._is_showed = false
    app.keyboard_manager:unregister_listener(self)
    for _, input in ipairs(self.inputs) do
        input:on_screen_hide()
    end
    Screen.hide(self)
end

function FormScreen:is_showed()
    return self._is_showed
end

function FormScreen:on_key_pressed(key)
    if key == "tab" then
        if app.keyboard_manager:is_key_down("lshift") then
            _advance_focus(self, -1)
        else
            _advance_focus(self, 1)
        end
        _notify_listeners(self)
    end
end

function FormScreen:add_input(input)
    -- assert_type(input, Input)
    table.insert(self.inputs, input)
end

function FormScreen:remove_input(input)
    -- assert_type(input, Input)
    local found = table.find_array_idx(self.inputs, input)
    assert(found)
    table.remove(self.inputs, found)
    if found == self._focus then
        self._focus = nil
    end
    if found == self.prev_focus then
        self.prev_focus = nil
    end
end

function FormScreen:read_only_change(input)
    -- assert_type(input, Input)
    local found = table.find_array_idx(self.inputs, input)
    assert(found)
    if found == self._focus then
        _advance_focus(self, 1)
    end
end

function FormScreen:focus(input)
    -- assert_type(input, Input)
    local found
    for i, v in ipairs(self.inputs) do
        if v == input then
            found = i
            break
        end
    end
    assert(found)
    self.prev_focus = self._focus
    self._focus = found
    _notify_listeners(self)
end

function FormScreen:remove_all_inputs()
    self.inputs = {}
    self.prev_focus = nil
    self._focus = nil
end

return FormScreen

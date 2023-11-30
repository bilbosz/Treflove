local Screen = require("screens.screen")
local KeyboardEventListener = require("events.keyboard").Listener
-- local Input = require("ui.input")

---@class FormScreen: Screen, KeyboardEventListener
local FormScreen = class("FormScreen", Screen, KeyboardEventListener)

local function NotifyListeners(self)
    if self.prevFocus == self._focus then
        return
    end
    local oldItem = self.inputs[self.prevFocus]
    if oldItem then
        oldItem:on_focus_lost()
    end
    local newItem = self.inputs[self._focus]
    if newItem then
        newItem:on_focus()
    end
end

local function AdvanceFocus(self, d)
    assert(d == 1 or d == -1)
    local inputs = self.inputs
    self.prevFocus = self._focus

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
    self.prevFocus = nil
    self._focus = nil
    self.isShowed = false
end

function FormScreen:show(...)
    Screen.show(self, ...)
    for _, input in ipairs(self.inputs) do
        input:on_screen_show()
    end
    app.keyboard_manager:register_listener(self)
    self.isShowed = true
end

function FormScreen:hide()
    self.isShowed = false
    app.keyboard_manager:unregister_listener(self)
    for _, input in ipairs(self.inputs) do
        input:on_screen_hide()
    end
    Screen.hide(self)
end

function FormScreen:is_showed()
    return self.isShowed
end

function FormScreen:on_key_pressed(key)
    if key == "tab" then
        if app.keyboard_manager:is_key_down("lshift") then
            AdvanceFocus(self, -1)
        else
            AdvanceFocus(self, 1)
        end
        NotifyListeners(self)
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
    if found == self.prevFocus then
        self.prevFocus = nil
    end
end

function FormScreen:read_only_change(input)
    -- assert_type(input, Input)
    local found = table.find_array_idx(self.inputs, input)
    assert(found)
    if found == self._focus then
        AdvanceFocus(self, 1)
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
    self.prevFocus = self._focus
    self._focus = found
    NotifyListeners(self)
end

function FormScreen:remove_all_inputs()
    self.inputs = {}
    self.prevFocus = nil
    self._focus = nil
end

return FormScreen

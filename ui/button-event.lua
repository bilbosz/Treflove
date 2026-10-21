local Input = require("ui.input")

---@class ButtonEventManager: Object
---@field private _buttons table<Control, Button> Registered button per control (weak keys)
---@field private _hover Button|nil Button currently under the pointer
---@field private _selection Button|nil Button pressed and not yet released
local ButtonEventManager = class("ButtonEventManager")

local WEAK_KEYS = {
    __mode = "k"
}

function ButtonEventManager:init()
    self._buttons = setmetatable({}, WEAK_KEYS)
    self._hover = nil
    self._selection = nil
end

---@param ctrl Control
---@param button Button
function ButtonEventManager:register(ctrl, button)
    self._buttons[ctrl] = button
end

---A button kept here would be driven after its control is hidden or dead.
---@param ctrl Control
function ButtonEventManager:unregister(ctrl)
    local button = self._buttons[ctrl]
    self._buttons[ctrl] = nil
    if not button then
        return
    end
    if self._selection == button then
        self._selection = nil
        if button:is_selected() then
            button:unselect()
        end
    end
    if self._hover == button then
        self._hover = nil
        button:leave()
    end
end

---@param ctrl Control
---@return boolean
local function _is_read_only_input(ctrl)
    if not is_instance_of(ctrl, Input) then
        return false
    end
    ---@cast ctrl Input
    return ctrl:is_read_only()
end

---@param ctrl Control
---@param buttons table<Control, Button>
---@param x number
---@param y number
---@return Button|nil
local function _find_button(ctrl, buttons, x, y)
    if not ctrl:is_visible() or not ctrl:get_global_recursive_aabb():is_point_inside(x, y) or _is_read_only_input(ctrl) then
        return nil
    end
    if buttons[ctrl] then
        return buttons[ctrl]
    end
    for _, child in ipairs(ctrl:get_children()) do
        local found = _find_button(child, buttons, x, y)
        if found then
            return found
        end
    end
    return nil
end

---@private
---@param x number
---@param y number
---@return Button|nil
function ButtonEventManager:_get_button(x, y)
    return _find_button(app.root, self._buttons, x, y)
end

---@param x number
---@param y number
---@param id PointerId
function ButtonEventManager:dispatch_pointer_down(x, y, id)
    assert(not self._selection)
    local selection = self:_get_button(x, y)
    if not selection then
        return
    end
    self._selection = selection
    selection:select()
end

---@param x number
---@param y number
---@param id PointerId
function ButtonEventManager:dispatch_pointer_up(x, y, id)
    local selection = self._selection
    local top = self:_get_button(x, y)
    if selection and selection == top then
        selection:unselect()
        selection:click()
    end
    self._selection = nil
end

---@param x number
---@param y number
---@param id PointerId
function ButtonEventManager:dispatch_pointer_move(x, y, id)
    local top = self:_get_button(x, y)
    local selection = self._selection
    local hover = self._hover
    if selection then
        if selection ~= top then
            selection:unselect()
        end
        if selection == top and selection ~= hover then
            selection:select()
        end
    end
    if hover ~= top then
        if hover then
            hover:leave()
        end
        if top then
            top:enter()
        end
    end
    self._hover = top
end

return ButtonEventManager

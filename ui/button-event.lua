local EventManager = require("events.event-manager")
local Control = require("controls.control")
local Input = require("ui.input")

---@class ButtonEventListener: Control
---@field _hovered boolean
---@field _selected boolean
local ButtonEventListener = class("ButtonEventListener", Control)

---@return void
function ButtonEventListener:init()
    self._selected = false
    self._hovered = false
end

---@return void
function ButtonEventListener:on_pointer_enter()
    self._hovered = true
end

---@return void
function ButtonEventListener:on_pointer_leave()
    self._hovered = false
end

---@return void
function ButtonEventListener:on_unselect()
    self._selected = false
end

---@return void
function ButtonEventListener:on_select()
    self._selected = true
end

---@return void
function ButtonEventListener:on_click()

end

---@return boolean
function ButtonEventListener:is_selected()
    return self._selected
end

---@return boolean
function ButtonEventListener:is_hovered()
    return self._hovered
end

---@class ButtonEventManager: EventManager
---@field private _hover nil|ButtonEventListener
---@field private _selection nil|ButtonEventListener
local ButtonEventManager = class("ButtonEventManager", EventManager)

---@param ctrl Control
---@param listeners table<Control, boolean>
---@param x number
---@param y number
---@return nil|Control|ButtonEventListener
local function _get_listener_internal(ctrl, listeners, x, y)
    if not ctrl:is_visible() or not ctrl:get_global_recursive_aabb():is_point_inside(x, y) or is_instance_of(ctrl, Input) and ctrl:is_read_only() then
        return nil
    end
    local top
    if listeners[ctrl] then
        top = ctrl
    end
    for _, child in ipairs(ctrl:get_children()) do
        top = top or _get_listener_internal(child, listeners, x, y)
    end
    return top
end

---@private
---@param x number
---@param y number
---@return nil|ButtonEventListener
function ButtonEventManager:_get_listener(x, y)
    return _get_listener_internal(app.root, select(2, next(self._methods)), x, y)
end

---@return void
function ButtonEventManager:init()
    EventManager.init(self, ButtonEventListener)
    self._hover = nil
    self._selection = nil
end

---@param x number
---@param y number
---@param id number
---@return void
function ButtonEventManager:pointer_down(x, y, id)
    assert(not self._selection)
    local selection = self:_get_listener(x, y)
    if not selection then
        return
    end
    self._selection = selection
    selection:on_select()
end

---@param x number
---@param y number
---@param id number
---@return void
function ButtonEventManager:pointer_up(x, y, id)
    local selection = self._selection
    local top = self:_get_listener(x, y)
    if selection and selection == top then
        selection:on_unselect()
        selection:on_click()
    end
    self._selection = nil
end

---@param x number
---@param y number
---@param id number
---@return void
function ButtonEventManager:pointer_move(x, y, id)
    local top = self:_get_listener(x, y)
    local selection = self._selection
    local hover = self._hover
    if selection then
        if selection ~= top then
            selection:on_unselect()
        end
        if selection == top and selection ~= hover then
            selection:on_select()
        end
    end
    if hover ~= top then
        if hover then
            hover:on_pointer_leave()
        end
        if top then
            top:on_pointer_enter()
        end
    end
    self._hover = top
end

return {
    Listener = ButtonEventListener,
    Manager = ButtonEventManager
}

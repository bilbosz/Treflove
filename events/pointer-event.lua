local Control = require("controls.control")
local EventManager = require("events.event-manager")

---@alias PointerId number|lightuserdata|nil Mouse button number, touch id, or nil for hover moves

---@class PointerEventListener: Control
---@field receive_through boolean|nil When true, the listener also receives events consumed by a listener above it
local PointerEventListener = class("PointerEventListener", Control)

---@param receive_through boolean|nil
function PointerEventListener:init(receive_through)
    self.receive_through = receive_through
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil pass_through True lets the event through to listeners below
function PointerEventListener:on_pointer_down(x, y, id)

end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil pass_through True lets the event through to listeners below
function PointerEventListener:on_pointer_up(x, y, id)

end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil pass_through True lets the event through to listeners below
function PointerEventListener:on_pointer_move(x, y, id)

end

---@class PointerEventManager: EventManager
---@field private _down_id PointerId Pointer id of the press currently being tracked
local PointerEventManager = class("PointerEventManager", EventManager)

---@param ctrl Control
---@param listeners table<PointerEventListener, function> Registered listener methods indexed by control
---@param x number
---@param y number
---@param list PointerEventListener[] Output list of hit listeners, in tree order
local function _get_listener_list(ctrl, listeners, x, y, list)
    if not ctrl:is_visible() or not ctrl:get_global_recursive_aabb():is_point_inside(x, y) then
        return nil
    end
    if listeners[ctrl] then
        table.insert(list, ctrl)
    end
    for _, child in ipairs(ctrl:get_children()) do
        _get_listener_list(child, listeners, x, y, list)
    end
end

function PointerEventManager:init()
    EventManager.init(self, PointerEventListener)
    self._down_id = nil
end

---@param x number
---@param y number
---@param id PointerId
function PointerEventManager:pointer_down(x, y, id)
    self._down_id = id
    self:invoke_event(PointerEventListener.on_pointer_down, x, y, id)
end

---@param x number
---@param y number
---@param id PointerId
function PointerEventManager:pointer_up(x, y, id)
    self:invoke_event(PointerEventListener.on_pointer_up, x, y, id)
    self._down_id = nil
end

---@param x number
---@param y number
---@param id PointerId
function PointerEventManager:pointer_move(x, y, id)
    self:invoke_event(PointerEventListener.on_pointer_move, x, y, id or self._down_id)
end

---@return number, number
function PointerEventManager:get_position()
    return love.mouse.getPosition()
end

---@param method function Listener class method identifying the event
---@param x number
---@param y number
---@param id PointerId
function PointerEventManager:invoke_event(method, x, y, id)
    local listeners = self._methods[method]
    ---@type PointerEventListener[]
    local list = {}
    _get_listener_list(app.root, listeners, x, y, list)
    local top_to_be_called = true
    for _, ctrl in ripairs(list) do
        local listener = listeners[ctrl]
        if top_to_be_called then
            local pass_through = listener(ctrl, x, y, id)
            if not pass_through then
                top_to_be_called = false
            end
        elseif ctrl.receive_through then
            listener(ctrl, x, y, id)
        end
    end
end

return {
    Listener = PointerEventListener,
    Manager = PointerEventManager
}

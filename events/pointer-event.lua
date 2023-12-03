local Control = require("controls.control")
local EventManager = require("events.event-manager")

---@class PointerEventListener: Control
local PointerEventListener = class("PointerEventListener", Control)

function PointerEventListener:init(receive_through)
    self.receive_through = receive_through
end

function PointerEventListener:on_pointer_down(x, y, id)

end

function PointerEventListener:on_pointer_up(x, y, id)

end

function PointerEventListener:on_pointer_move(x, y, id)

end

---@class PointerEventManager: EventManager
local PointerEventManager = class("PointerEventManager", EventManager)

local function GetListenerList(ctrl, listeners, x, y, list)
    if not ctrl:is_visible() or not ctrl:get_global_recursive_aabb():is_point_inside(x, y) then
        return nil
    end
    if listeners[ctrl] then
        table.insert(list, ctrl)
    end
    for _, child in ipairs(ctrl:get_children()) do
        GetListenerList(child, listeners, x, y, list)
    end
end

function PointerEventManager:init()
    EventManager.init(self, PointerEventListener)
    self.down_id = nil
end

function PointerEventManager:pointer_down(x, y, id)
    self.down_id = id
    self:invoke_event(PointerEventListener.on_pointer_down, x, y, id)
end

function PointerEventManager:pointer_up(x, y, id)
    self:invoke_event(PointerEventListener.on_pointer_up, x, y, id)
    self.down_id = nil
end

function PointerEventManager:pointer_move(x, y, id)
    self:invoke_event(PointerEventListener.on_pointer_move, x, y, id or self.down_id)
end

function PointerEventManager:get_position()
    return love.mouse.getPosition()
end

function PointerEventManager:invoke_event(method, x, y, id)
    local listeners = self._methods[method]
    local list = {}
    GetListenerList(app.root, listeners, x, y, list)
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

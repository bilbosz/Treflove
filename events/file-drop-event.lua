local Control = require("controls.control")
local EventManager = require("events.event-manager")

---@class FileSystemDropEventListener: Control
local FileSystemDropEventListener = class("FileSystemDropEventListener", Control)

function FileSystemDropEventListener:init(receive_through)
    self.receive_through = receive_through
end

function FileSystemDropEventListener:on_file_system_drop(x, y, dropped_file)

end

---@class FileSystemDropEventManager: EventManager
local FileSystemDropEventManager = class("FileSystemDropEventManager", EventManager)

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

function FileSystemDropEventManager:init()
    EventManager.init(self, FileSystemDropEventListener)
end

function FileSystemDropEventManager:file_drop(dropped_file)
    local x, y = app.pointer_event_manager:get_position()
    self:invoke_event(FileSystemDropEventListener.on_file_system_drop, x, y, dropped_file)
end

function FileSystemDropEventManager:invoke_event(method, x, y, dropped_file)
    local listeners = self._methods[method]
    local list = {}
    GetListenerList(app.root, listeners, x, y, list)
    local top_to_be_called = true
    for _, ctrl in ripairs(list) do
        local listener = listeners[ctrl]
        if top_to_be_called then
            local pass_through = listener(ctrl, x, y, dropped_file)
            if not pass_through then
                top_to_be_called = false
            end
        elseif ctrl.receive_through then
            listener(ctrl, x, y, dropped_file)
        end
    end
end

return {
    Listener = FileSystemDropEventListener,
    Manager = FileSystemDropEventManager
}

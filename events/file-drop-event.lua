local Control = require("controls.control")
local EventManager = require("events.event-manager")

---@class FileSystemDropEventListener: Control
---@field receive_through boolean|nil When true, the listener also receives events consumed by a listener above it
local FileSystemDropEventListener = class("FileSystemDropEventListener", Control)

---@param receive_through boolean|nil
function FileSystemDropEventListener:init(receive_through)
    self.receive_through = receive_through
end

---@param x number
---@param y number
---@param dropped_file love.DroppedFile
---@return boolean|nil pass_through True lets the event through to listeners below
function FileSystemDropEventListener:on_file_system_drop(x, y, dropped_file)

end

---@class FileSystemDropEventManager: EventManager
local FileSystemDropEventManager = class("FileSystemDropEventManager", EventManager)

---@param ctrl Control
---@param listeners table<FileSystemDropEventListener, function> Registered listener methods indexed by control
---@param x number
---@param y number
---@param list FileSystemDropEventListener[] Output list of hit listeners, in tree order
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

function FileSystemDropEventManager:init()
    EventManager.init(self, FileSystemDropEventListener)
end

---@param dropped_file love.DroppedFile
function FileSystemDropEventManager:file_drop(dropped_file)
    local x, y = app.pointer_event_manager:get_position()
    self:invoke_event(FileSystemDropEventListener.on_file_system_drop, x, y, dropped_file)
end

---@param method function Listener class method identifying the event
---@param x number
---@param y number
---@param dropped_file love.DroppedFile
function FileSystemDropEventManager:invoke_event(method, x, y, dropped_file)
    local listeners = self._methods[method]
    ---@type FileSystemDropEventListener[]
    local list = {}
    _get_listener_list(app.root, listeners, x, y, list)
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

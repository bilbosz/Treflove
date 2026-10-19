local Event = require("events.event")
local hit_test = require("events.hit-test")

---@alias FileDroppedHandler fun(ctrl: Control, x: number, y: number, dropped_file: love.DroppedFile): boolean|nil Return truthy to let the event through to controls below

---@class FileSystemDropEventManager: Object
---@field public file_dropped Event Hit-tested with (x, y, dropped_file) at the pointer position
---@field private _receive_through ReceiveThroughSet
local FileSystemDropEventManager = class("FileSystemDropEventManager")

function FileSystemDropEventManager:init()
    self.file_dropped = Event()
    self._receive_through = hit_test.make_receive_through_set()
end

---@param ctrl Control
---@param value boolean
function FileSystemDropEventManager:set_receive_through(ctrl, value)
    self._receive_through[ctrl] = value or nil
end

---@param dropped_file love.DroppedFile
function FileSystemDropEventManager:file_drop(dropped_file)
    local x, y = app.pointer_event_manager:get_position()
    hit_test.dispatch(self.file_dropped, self._receive_through, x, y, dropped_file)
end

return FileSystemDropEventManager

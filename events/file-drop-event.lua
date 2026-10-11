local Event = require("events.event")
local hit_test = require("events.hit-test")

---@alias FileDroppedHandler fun(ctrl: Control, x: number, y: number, dropped_file: love.DroppedFile): boolean|nil Return truthy to let the event through to controls below

---Dispatches files dropped onto the window to Controls under the pointer.
---Owners of the `file_dropped` event are always Controls and their handlers
---(see `FileDroppedHandler`) receive `(ctrl, x, y, dropped_file)`:
---`app.file_system_drop_event_manager.file_dropped:register(self, self.on_file_system_drop)`.
---
---Dispatch is hit-tested exactly like pointer events (see
---`events/hit-test.lua`): top-most control first, a falsy return consumes the
---drop. A control that must also receive drops consumed above it opts in with
---`app.file_system_drop_event_manager:set_receive_through(self, true)`.
---@class FileSystemDropEventManager
---@field public file_dropped Event Hit-tested with (x, y, dropped_file) at the pointer position
---@field private _receive_through ReceiveThroughSet
local FileSystemDropEventManager = class("FileSystemDropEventManager")

function FileSystemDropEventManager:init()
    self.file_dropped = Event()
    self._receive_through = hit_test.make_receive_through_set()
end

---Let `ctrl` also receive file drops consumed by a control above it.
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

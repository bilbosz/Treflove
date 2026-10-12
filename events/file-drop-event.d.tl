-- events/file-drop-event.tlt

-- The handler of `file_dropped`, registered by a Control; a truthy return
-- lets the drop through to the controls below.
global type FileDroppedHandler = function(ctrl: Control, x: number, y: number, dropped_file: love.DroppedFile): boolean

global interface FileSystemDropEventManager is Object
    -- Hit-tested with (x, y, dropped_file) at the pointer position.
    file_dropped: Event
    _receive_through: ReceiveThroughSet
    set_receive_through: function(self, ctrl: Control, value: boolean)
    file_drop: function(self, dropped_file: love.DroppedFile)
end

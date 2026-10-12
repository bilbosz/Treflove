-- events/hit-test.lua (still Lua): the hit-tested dispatch shared by
-- PointerEventManager and FileSystemDropEventManager (docs/architecture.md,
-- "Event System").

-- Controls that also receive events consumed above them (weak keys).
global type ReceiveThroughSet = {Control: boolean}

global record HitTest
    make_receive_through_set: function(): ReceiveThroughSet
    -- Calls the handlers of `event` registered by the controls under (x, y)
    -- as `handler(ctrl, x, y, ...)`, top-most first. any: the extra
    -- arguments of the event (a PointerId, a love.DroppedFile).
    dispatch: function(event: Event, receive_through: ReceiveThroughSet, x: number, y: number, ...: any)
end

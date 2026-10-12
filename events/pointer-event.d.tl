-- events/pointer-event.lua (still Lua)

-- A mouse button number, a touch id (light userdata), or nil for a hover
-- move.
global type PointerId = number | userdata

-- The handler of a pointer event, registered by a Control on
-- `pointer_down`, `pointer_up` or `pointer_move`; a truthy return lets the
-- event through to the controls below.
global type PointerEventHandler = function(ctrl: Control, x: number, y: number, id: PointerId): boolean

global interface PointerEventManager is Object
    pointer_down: Event -- hit-tested with (x, y, id)
    pointer_up: Event -- hit-tested with (x, y, id)
    -- Hit-tested with (x, y, id); id is the pressed pointer for mouse
    -- drags, nil for hover.
    pointer_move: Event
    _receive_through: ReceiveThroughSet
    _down_id: PointerId -- the pointer of the press currently tracked
    set_receive_through: function(self, ctrl: Control, value: boolean)
    dispatch_pointer_down: function(self, x: number, y: number, id: PointerId)
    dispatch_pointer_up: function(self, x: number, y: number, id: PointerId)
    dispatch_pointer_move: function(self, x: number, y: number, id: PointerId)
    get_position: function(self): number, number
end

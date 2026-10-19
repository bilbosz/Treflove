local Event = require("events.event")
local hit_test = require("events.hit-test")

---@alias PointerId number|lightuserdata|nil Mouse button number, touch id, or nil for hover moves

---@alias PointerEventHandler fun(ctrl: Control, x: number, y: number, id: PointerId): boolean|nil Return truthy to let the event through to controls below

---@class PointerEventManager: Object
---@field public pointer_down Event Hit-tested with (x, y, id)
---@field public pointer_up Event Hit-tested with (x, y, id)
---@field public pointer_move Event Hit-tested with (x, y, id); id is the pressed pointer for mouse drags, nil for hover
---@field private _receive_through ReceiveThroughSet
---@field private _down_id PointerId Pointer id of the press currently being tracked
local PointerEventManager = class("PointerEventManager")

function PointerEventManager:init()
    self.pointer_down = Event()
    self.pointer_up = Event()
    self.pointer_move = Event()
    self._receive_through = hit_test.make_receive_through_set()
    self._down_id = nil
end

---@param ctrl Control
---@param value boolean
function PointerEventManager:set_receive_through(ctrl, value)
    self._receive_through[ctrl] = value or nil
end

---@param x number
---@param y number
---@param id PointerId
function PointerEventManager:dispatch_pointer_down(x, y, id)
    self._down_id = id
    hit_test.dispatch(self.pointer_down, self._receive_through, x, y, id)
end

---@param x number
---@param y number
---@param id PointerId
function PointerEventManager:dispatch_pointer_up(x, y, id)
    hit_test.dispatch(self.pointer_up, self._receive_through, x, y, id)
    self._down_id = nil
end

---@param x number
---@param y number
---@param id PointerId Nil for mouse moves; the id of the current press is used instead
function PointerEventManager:dispatch_pointer_move(x, y, id)
    hit_test.dispatch(self.pointer_move, self._receive_through, x, y, id or self._down_id)
end

---@return number, number
function PointerEventManager:get_position()
    return love.mouse.getPosition()
end

return PointerEventManager

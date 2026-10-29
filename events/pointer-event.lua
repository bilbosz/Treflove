local Event = require("events.event")
local hit_test = require("events.hit-test")
local lifetime = require("lifetime")

---@alias PointerId number|lightuserdata|nil Mouse button number, touch id, or nil for hover moves

---@alias PointerEventHandler fun(ctrl: Control, x: number, y: number, id: PointerId): boolean|nil Return truthy to let the event through to controls below

---@alias WheelEventHandler fun(ctrl: Control, x: number, y: number, dx: number, dy: number): boolean|nil Return truthy to let the event through to controls below

---@class PointerEventManager: Object
---@field public pointer_down Event Hit-tested with (x, y, id)
---@field public pointer_up Event Hit-tested with (x, y, id)
---@field public pointer_move Event Hit-tested with (x, y, id); id is the pressed pointer for mouse drags, nil for hover
---@field public wheel Event Hit-tested at the pointer position with (x, y, dx, dy), the wheel movement: `dx` to the right, `dy` away from the user, as LÖVE gives them
---@field private _receive_through ReceiveThroughSet
---@field private _wheel_receive_through ReceiveThroughSet Of its own: a control that receives the pointer events consumed above it still has the wheel taken by what is over it
---@field private _down_id PointerId Pointer id of the press currently being tracked
---@field private _captors table<PointerId, Control> By the press each holds: its moves and its release go to the captor alone
local PointerEventManager = class("PointerEventManager")

function PointerEventManager:init()
    self.pointer_down = Event()
    self.pointer_up = Event()
    self.pointer_move = Event()
    self.wheel = Event()
    self._receive_through = hit_test.make_receive_through_set()
    self._wheel_receive_through = hit_test.make_receive_through_set()
    self._down_id = nil
    self._captors = {}
end

---@param ctrl Control
---@param id PointerId The press, never nil
function PointerEventManager:capture(ctrl, id)
    assert(id ~= nil)
    self._captors[id] = ctrl
end

---@param ctrl Control
function PointerEventManager:release_capture(ctrl)
    for id, captor in pairs(self._captors) do
        if captor == ctrl then
            self._captors[id] = nil
        end
    end
end

---@param id PointerId The press
---@return Control|nil
function PointerEventManager:get_captor(id)
    return self._captors[id]
end

---@private
---@param id PointerId The press
---@return Control|nil The live captor of the press; one that died let go
function PointerEventManager:_captor_of(id)
    if id == nil then
        return nil
    end
    local captor = self._captors[id]
    if captor and not lifetime.alive(captor) then
        self._captors[id] = nil
        return nil
    end
    return captor
end

---@param captor Control
---@param event Event
---@param x number
---@param y number
---@param id PointerId
local function _deliver(captor, event, x, y, id)
    local handler = event:get_handler(captor)
    ---@cast handler PointerEventHandler|nil
    if handler then
        handler(captor, x, y, id)
    end
end

---@param ctrl Control
---@param value boolean
function PointerEventManager:set_receive_through(ctrl, value)
    self._receive_through[ctrl] = value or nil
end

---@param ctrl Control
---@param value boolean
function PointerEventManager:set_wheel_receive_through(ctrl, value)
    self._wheel_receive_through[ctrl] = value or nil
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
    local captor = self:_captor_of(id)
    if captor then
        self._captors[assert(id)] = nil
        _deliver(captor, self.pointer_up, x, y, id)
    else
        hit_test.dispatch(self.pointer_up, self._receive_through, x, y, id)
    end
    self._down_id = nil
end

---@param x number
---@param y number
---@param id PointerId Nil for mouse moves; the id of the current press is used instead
function PointerEventManager:dispatch_pointer_move(x, y, id)
    ---@type table<Control, boolean>
    local held = {}
    for press in pairs(self._captors) do
        local captor = self:_captor_of(press)
        if captor and (id == nil or id == press) then
            held[captor] = true
        end
    end
    if next(held) == nil then
        hit_test.dispatch(self.pointer_move, self._receive_through, x, y, id or self._down_id)
        return
    end
    for captor in pairs(held) do
        _deliver(captor, self.pointer_move, x, y, id or self._down_id)
    end
end

---@param dx number
---@param dy number
function PointerEventManager:dispatch_wheel(dx, dy)
    local x, y = self:get_position()
    hit_test.dispatch(self.wheel, self._wheel_receive_through, x, y, dx, dy)
end

---@return number, number
function PointerEventManager:get_position()
    return love.mouse.getPosition()
end

return PointerEventManager

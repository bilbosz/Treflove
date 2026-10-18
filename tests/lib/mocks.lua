---Test doubles for the parts of the runtime that tests must control:
---the global `app`, LÖVE channels/threads, and `love.data` compression.
local Event = require("events.event")
local FileSystemDropEventManager = require("events.file-drop-event")
local KeyboardManager = require("events.keyboard")
local PointerEventManager = require("events.pointer-event")

local mocks = {}

-- The real pointer manager with the pointer position under test control
-- instead of `love.mouse` (file drops are dispatched at this position).
---@class TestPointerEventManager: PointerEventManager
---@field position [number, number]
local TestPointerEventManager = class("TestPointerEventManager", PointerEventManager)

function TestPointerEventManager:init()
    PointerEventManager.init(self)
    self.position = {
        0,
        0
    }
end

---@return number, number
function TestPointerEventManager:get_position()
    return self.position[1], self.position[2]
end

---Stand-in for the `love.keyboard` module (what `TextEventManager` talks to):
---text input state and held keys are plain fields tests can set.
---@return FakeKeyboard
function mocks.make_keyboard()
    ---@class FakeKeyboard
    ---@field text_input boolean
    ---@field key_repeat boolean
    ---@field down table<love.KeyConstant, boolean> Keys reported as held by `isDown`
    local keyboard = {
        text_input = false,
        key_repeat = false,
        down = {}
    }

    ---@param enable boolean
    function keyboard.setTextInput(enable)
        keyboard.text_input = enable
    end

    ---@return boolean
    function keyboard.hasTextInput()
        return keyboard.text_input
    end

    ---@param enable boolean
    function keyboard.setKeyRepeat(enable)
        keyboard.key_repeat = enable
    end

    ---@param ... love.KeyConstant
    ---@return boolean
    function keyboard.isDown(...)
        for _, key in ipairs({
            ...
        }) do
            if keyboard.down[key] then
                return true
            end
        end
        return false
    end

    return keyboard
end

---@param overrides table|nil Fields merged over the defaults
---@return AppMock
function mocks.make_app(overrides)
    ---@class AppMock: App
    ---@field logs any[][] Arguments of every `app:log` call, in order
    ---@field update_event Event Real event instance, triggerable by tests
    ---@field wheel_event Event Real event instance, triggerable by tests
    ---@field keyboard_manager KeyboardManager Real manager
    ---@field resize_manager ResizeManagerMock Only the `resized` event (no window behind it)
    ---@field pointer_event_manager TestPointerEventManager Real manager, position set by `set_pointer_position`
    ---@field file_system_drop_event_manager FileSystemDropEventManager Real manager
    ---@field private _time number
    local app_mock = {
        is_client = true,
        is_server = false,
        logs = {},
        _time = 0
    }

    ---@return number
    function app_mock:get_time()
        return self._time
    end

    ---Advance the fake clock; `app:get_time()` reflects it immediately.
    ---@param dt number
    function app_mock:advance_time(dt)
        self._time = self._time + dt
    end

    ---@param ... any
    function app_mock:log(...)
        table.insert(self.logs, {
            ...
        })
    end

    ---Move the fake pointer (what `pointer_event_manager:get_position()` returns).
    ---@param x number
    ---@param y number
    function app_mock:set_pointer_position(x, y)
        self.pointer_event_manager.position[1], self.pointer_event_manager.position[2] = x, y
    end

    ---@class ResizeManagerMock
    ---@field resized Event
    local resize_manager = {
        resized = Event()
    }

    app_mock.update_event = Event()
    app_mock.wheel_event = Event()
    app_mock.keyboard_manager = KeyboardManager()
    app_mock.resize_manager = resize_manager
    app_mock.pointer_event_manager = TestPointerEventManager()
    app_mock.file_system_drop_event_manager = FileSystemDropEventManager()

    if overrides then
        table.merge(app_mock, overrides)
    end
    return app_mock
end

---Replace the global `app` with a fresh mock and return it.
---@param overrides table|nil
---@return AppMock
function mocks.install_app(overrides)
    local app_mock = mocks.make_app(overrides)
    app = app_mock
    return app_mock
end

---In-memory stand-in for a `love.Channel` (no threads involved).
---@return FakeChannel
function mocks.make_channel()
    ---@class FakeChannel
    ---@field _queue any[]
    ---@field _released boolean|nil
    local channel = {
        _queue = {}
    }

    ---@param value any
    function channel:push(value)
        table.insert(self._queue, value)
    end

    ---@return any
    function channel:pop()
        return table.remove(self._queue, 1)
    end

    ---@return any
    function channel:demand()
        local value = self:pop()
        assert(value ~= nil, "demand() on an empty fake channel would block forever")
        return value
    end

    ---@return number
    function channel:getCount()
        return #self._queue
    end

    function channel:release()
        self._released = true
    end

    return channel
end

---Stand-in for a `love.Thread`.
---@return table
function mocks.make_thread()
    local thread = {}

    function thread:release()
        self._released = true
    end

    return thread
end

---Make sure `love.data.compress`/`decompress`/`encode`/`hash` exist. Under
---`love . test` the real implementations are used; under plain LuaJIT
---reversible string-passthrough fakes are installed instead (`hash` is a
---plain string hash, deterministic, not cryptographic).
function mocks.ensure_love_data()
    if love and love.data then
        return
    end
    local PREFIX = "fake-compressed:"
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.data = {
        compress = function(_, _, str)
            return PREFIX .. str
        end,
        decompress = function(_, _, payload)
            return string.sub(payload, #PREFIX + 1)
        end,
        encode = function(_, _, str)
            return (string.gsub(str, ".", function(c)
                return string.format("%02x", string.byte(c))
            end))
        end,
        hash = function(_, str)
            local h = 5381
            for i = 1, #str do
                h = (h * 33 + string.byte(str, i)) % 4294967296
            end
            return string.format("%08x", h)
        end
    }
end

---A 2D affine transform standing in for a `love.Transform`: what
---`Control` needs (`setTransformation`, `setMatrix`, `getMatrix`, `apply`,
---`inverse`, `transformPoint`, `inverseTransformPoint`). Column-major as
---LÖVE's: x' = a*x + c*y + tx, y' = b*x + d*y + ty.
---@class FakeTransform
---@field a number
---@field b number
---@field c number
---@field d number
---@field tx number
---@field ty number
local FakeTransform = {}
FakeTransform.__index = FakeTransform

---@return FakeTransform
local function _new_transform()
    return setmetatable({
        a = 1,
        b = 0,
        c = 0,
        d = 1,
        tx = 0,
        ty = 0
    }, FakeTransform)
end

---@param x number
---@param y number
---@param angle number
---@param sx number
---@param sy number
---@param ox number
---@param oy number
---@return FakeTransform
function FakeTransform:setTransformation(x, y, angle, sx, sy, ox, oy)
    local cos, sin = math.cos(angle), math.sin(angle)
    self.a, self.b = cos * sx, sin * sx
    self.c, self.d = -sin * sy, cos * sy
    self.tx = x - (self.a * ox + self.c * oy)
    self.ty = y - (self.b * ox + self.d * oy)
    return self
end

---@param ... number The 16 elements of a row-major 4x4 matrix, as `getMatrix` returns them
---@return FakeTransform
function FakeTransform:setMatrix(...)
    local e1, e2, _, e4, e5, e6, _, e8 = ...
    self.a, self.c, self.tx = e1, e2, e4
    self.b, self.d, self.ty = e5, e6, e8
    return self
end

---@return number ...
function FakeTransform:getMatrix()
    return self.a, self.c, 0, self.tx, self.b, self.d, 0, self.ty, 0, 0, 1, 0, 0, 0, 0, 1
end

---@param other FakeTransform
---@return FakeTransform
function FakeTransform:apply(other)
    local a, b, c, d, tx, ty = self.a, self.b, self.c, self.d, self.tx, self.ty
    self.a = a * other.a + c * other.b
    self.b = b * other.a + d * other.b
    self.c = a * other.c + c * other.d
    self.d = b * other.c + d * other.d
    self.tx = a * other.tx + c * other.ty + tx
    self.ty = b * other.tx + d * other.ty + ty
    return self
end

---@return FakeTransform
function FakeTransform:inverse()
    local det = self.a * self.d - self.b * self.c
    local inv = _new_transform()
    inv.a, inv.b, inv.c, inv.d = self.d / det, -self.b / det, -self.c / det, self.a / det
    inv.tx = -(inv.a * self.tx + inv.c * self.ty)
    inv.ty = -(inv.b * self.tx + inv.d * self.ty)
    return inv
end

---@param x number
---@param y number
---@return number, number
function FakeTransform:transformPoint(x, y)
    return self.a * x + self.c * y + self.tx, self.b * x + self.d * y + self.ty
end

---@param x number
---@param y number
---@return number, number
function FakeTransform:inverseTransformPoint(x, y)
    return self:inverse():transformPoint(x, y)
end

---Make sure `love.math.newTransform` and `love.math.newRandomGenerator`
---exist, so that real `Control`s (and the login's salt) can be built under
---plain LuaJIT. Under `love . test` the real implementations are used.
function mocks.ensure_love_math()
    if love and love.math then
        return
    end
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.math = {
        newTransform = _new_transform,
        newRandomGenerator = function()
            local state = 1
            return {
                setSeed = function(_, seed)
                    state = seed % 2147483647
                end,
                random = function(_, lo, hi)
                    state = (state * 16807) % 2147483647
                    return lo + state % (hi - lo + 1)
                end
            }
        end
    }
end

return mocks

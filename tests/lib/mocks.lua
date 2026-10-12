---Test doubles for the parts of the runtime that tests must control:
---the global `app`, LÖVE channels/threads, and `love.data` compression.
local Event = require("events.event")
local FileSystemDropEventManager = require("events.file-drop-event")
local KeyboardManager = require("events.keyboard")
local PointerEventManager = require("events.pointer-event")
local table_utils = require("utils.table")

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
        table_utils.merge(app_mock, overrides)
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

---Make sure `love.data.compress`/`decompress` exist. Under `love . test` the
---real implementations are used; under plain LuaJIT a reversible
---string-passthrough fake is installed instead.
function mocks.ensure_love_data()
    if love and love.data then
        return
    end
    local PREFIX = "fake-compressed:"
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = {
        data = {
            compress = function(_, _, str)
                return PREFIX .. str
            end,
            decompress = function(_, _, payload)
                return string.sub(payload, #PREFIX + 1)
            end
        }
    }
end

---Make sure `love.math.newTransform` exists, for code that constructs a
---`Control` (a `Screen` makes one). Under `love . test` the real module is
---used; under plain LuaJIT a transform that ignores every operation is
---installed instead (enough for constructing controls, not for geometry).
function mocks.ensure_love_math()
    if love and love.math then
        return
    end
    local transform_mt = {}
    transform_mt.__index = function()
        return function(transform)
            return transform
        end
    end
    ---@diagnostic disable-next-line: assign-type-mismatch
    love = love or {}
    love.math = {
        newTransform = function()
            return setmetatable({}, transform_mt)
        end
    }
end

return mocks

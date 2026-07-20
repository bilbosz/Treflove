---Test doubles for the parts of the runtime that tests must control:
---the global `app`, LÖVE channels/threads, and `love.data` compression.
local mocks = {}

---@param overrides table|nil Fields merged over the defaults
---@return AppMock
function mocks.make_app(overrides)
    ---@class AppMock: App
    ---@field logs any[][] Arguments of every `app:log` call, in order
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

    ---@return table
    local function _stub_event_manager()
        return {
            register_listener = function()
            end,
            unregister_listener = function()
            end
        }
    end

    app_mock.update_event_manager = _stub_event_manager()
    app_mock.keyboard_manager = _stub_event_manager()

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

return mocks

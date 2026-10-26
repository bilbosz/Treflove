local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Consts = require("app.consts")
local MonitorTarget = require("app.monitor-target")
local lifetime = require("lifetime")

---@return TestMonitorSocket
local function make_socket()
    ---@class TestMonitorSocket: ConsoleSocket
    ---@field arriving string Sent by the console, not yet received
    ---@field peer_closed boolean The console closed: once `arriving` is empty, `receive` says "closed"
    ---@field refuse boolean `connect` fails
    ---@field sent string Everything sent, not yet taken by `take_sent`
    ---@field address string|nil
    ---@field port integer|nil
    ---@field closed boolean
    local fake = {
        arriving = "",
        peer_closed = false,
        refuse = false,
        sent = "",
        address = nil,
        port = nil,
        closed = false
    }

    ---@param address string
    ---@param port integer
    ---@return integer|nil, string|nil
    function fake:connect(address, port)
        self.address, self.port = address, port
        if self.refuse then
            return nil, "connection refused"
        end
        return 1, nil
    end

    function fake:settimeout()
    end

    ---@param data string
    ---@param i integer|nil
    ---@return integer|nil, string|nil, integer|nil
    function fake:send(data, i)
        self.sent = self.sent .. string.sub(data, i or 1)
        return #data, nil, nil
    end

    ---@param pattern "*l"|integer
    ---@return string|nil, string|nil, string|nil
    function fake:receive(pattern)
        if pattern == "*l" then
            local newline = string.find(self.arriving, "\n", 1, true)
            if newline then
                local line = string.sub(self.arriving, 1, newline - 1)
                self.arriving = string.sub(self.arriving, newline + 1)
                return line, nil, nil
            end
        elseif type(pattern) == "number" and #self.arriving >= pattern then
            local data = string.sub(self.arriving, 1, pattern)
            self.arriving = string.sub(self.arriving, pattern + 1)
            return data, nil, nil
        end
        local partial = self.arriving
        self.arriving = ""
        return nil, self.peer_closed and "closed" or "timeout", partial
    end

    function fake:close()
        self.closed = true
    end

    return fake
end

---@param kind string
---@param body string
---@return string
local function frame(kind, body)
    return string.format("%s %d\n%s", kind, #body, body)
end

---@param fake TestMonitorSocket
---@return string[] The chunk of every eval frame sent since the last call
local function take_sent(fake)
    ---@type string[]
    local chunks = {}
    local sent = fake.sent
    while sent ~= "" do
        local kind, length, rest = string.match(sent, "^(%l+) (%d+)\n(.*)$")
        assert(kind == "eval", "the monitor sends evals")
        local n = assert(tonumber(length))
        table.insert(chunks, string.sub(rest, 1, n))
        sent = string.sub(rest, n + 1)
    end
    fake.sent = ""
    return chunks
end

---@class TestMonitorSide
---@field app AppMock
---@field target MonitorTarget
---@field sockets TestMonitorSocket[] Every socket the target made, in order

---@param refusals integer|nil How many connection attempts fail first
---@return TestMonitorSide
local function make_target(refusals)
    local app_mock = mocks.install_app()
    ---@type TestMonitorSocket[]
    local sockets = {}
    local target = MonitorTarget("client", "127.0.0.1", "9400", function()
        local fake = make_socket()
        fake.refuse = #sockets < (refusals or 0)
        table.insert(sockets, fake)
        return fake
    end)
    return {
        app = app_mock,
        target = target,
        sockets = sockets
    }
end

---@param side TestMonitorSide
---@return TestMonitorSocket
local function connected(side)
    side.target:update(0)
    test.assert_eq(side.target:get_state(), "connected")
    local fake = side.sockets[#side.sockets]
    take_sent(fake)
    return fake
end

---@param side TestMonitorSide
---@param seconds number
local function advance(side, seconds)
    side.app:advance_time(seconds)
    side.target:update(seconds)
end

test.suite("MonitorTarget")

test.case("connects at its first update to the host and port and streams the log", function()
    local side = make_target()
    test.assert_eq(side.target:get_state(), "connecting")
    test.assert_eq(#side.sockets, 0, "not before the update")
    side.target:update(0)
    test.assert_eq(side.target:get_state(), "connected")
    local fake = side.sockets[1]
    test.assert_eq(fake.address, "127.0.0.1")
    test.assert_eq(fake.port, 9400)
    test.assert_deep_eq(take_sent(fake), {
        "log(true)"
    })
    test.assert_deep_eq(side.app.logs, {
        {
            "monitor: client connected to 127.0.0.1:9400"
        }
    })
    lifetime.destroy(side.target)
    test.assert_true(fake.closed)
end)

test.case("a refused connection is tried again after the reconnection delay of the app's clock", function()
    local side = make_target(2)
    side.target:update(0)
    test.assert_eq(side.target:get_state(), "connecting")
    test.assert_true(side.sockets[1].closed)
    advance(side, Consts.MONITOR_RECONNECT_SECONDS * 0.5)
    test.assert_eq(#side.sockets, 1, "not before the delay")
    advance(side, Consts.MONITOR_RECONNECT_SECONDS * 0.5)
    test.assert_eq(#side.sockets, 2)
    test.assert_eq(side.target:get_state(), "connecting")
    advance(side, Consts.MONITOR_RECONNECT_SECONDS)
    test.assert_eq(#side.sockets, 3)
    test.assert_eq(side.target:get_state(), "connected")
    test.assert_deep_eq(take_sent(side.sockets[3]), {
        "log(true)"
    })
end)

test.case("a closed connection is closed until the delay passes, then connects again, its watches forgotten until reported", function()
    local side = make_target()
    local fake = connected(side)
    fake.arriving = frame("watch", "hp\t1\t0.000\t10")
    side.target:update(0)
    test.assert_eq(side.target:get_watches().hp.value, "10")
    fake.peer_closed = true
    side.target:update(0)
    test.assert_eq(side.target:get_state(), "closed")
    test.assert_true(fake.closed)
    advance(side, Consts.MONITOR_RECONNECT_SECONDS * 0.5)
    test.assert_eq(#side.sockets, 1)
    test.assert_eq(side.target:get_state(), "closed")
    advance(side, Consts.MONITOR_RECONNECT_SECONDS * 0.5)
    test.assert_eq(side.target:get_state(), "connected")
    local again = side.sockets[2]
    test.assert_deep_eq(take_sent(again), {
        "log(true)"
    })
    test.assert_deep_eq(side.target:get_watches(), {})
    again.arriving = frame("watch", "hp\t5\t1.000\t9")
    side.target:update(0)
    test.assert_deep_eq(side.target:get_watches(), {
        hp = {
            value = "9",
            frame = 5,
            time = 1
        }
    })
end)

test.case("watch and log frames are stored, each a change of the revision", function()
    local side = make_target()
    local fake = connected(side)
    local revision = side.target:get_revision()
    fake.arriving = frame("watch", "hp\t7\t0.500\t10\t{a = 1}") .. frame("log", "first line") .. frame("log", "two\nlines")
    side.target:update(0)
    test.assert_deep_eq(side.target:get_watches(), {
        hp = {
            value = "10\t{a = 1}",
            frame = 7,
            time = 0.5
        }
    })
    test.assert_deep_eq(side.target:get_log(), {
        "first line",
        "two",
        "lines"
    })
    test.assert_eq(side.target:get_log_end(), 3)
    test.assert_true(side.target:get_revision() > revision)
    revision = side.target:get_revision()
    side.target:update(0)
    test.assert_eq(side.target:get_revision(), revision, "nothing arrived")
end)

test.case("the log keeps its last lines, numbered from the first ever appended", function()
    local side = make_target()
    local limit = Consts.MONITOR_LOG_LINES
    for i = 1, limit + 2 do
        side.target:append_log("line " .. i)
    end
    local log = side.target:get_log()
    test.assert_eq(#log, limit)
    test.assert_eq(log[1], "line 3")
    test.assert_eq(log[limit], "line " .. (limit + 2))
    test.assert_eq(side.target:get_log_end(), limit + 2)
end)

test.case("evaluate sends the chunk and hands its ok or error reply to the callback", function()
    local side = make_target()
    ---@type {[1]: boolean, [2]: string}[]
    local replies = {}
    ---@param ok boolean
    ---@param body string
    local function on_reply(ok, body)
        table.insert(replies, {
            ok,
            body
        })
    end
    side.target:evaluate("return 1", on_reply)
    test.assert_deep_eq(replies, {
        {
            false,
            "client is not connected"
        }
    }, "at once without a connection")
    replies = {}
    local fake = connected(side)
    side.target:evaluate("return 1 + 1", on_reply)
    side.target:evaluate("error('no')", on_reply)
    test.assert_deep_eq(take_sent(fake), {
        "return 1 + 1",
        "error('no')"
    })
    fake.arriving = frame("ok", "") .. frame("ok", "2") .. frame("error", "no\ntraceback")
    side.target:update(0)
    test.assert_deep_eq(replies, {
        {
            true,
            "2"
        },
        {
            false,
            "no\ntraceback"
        }
    }, "the reply of log(true) is nobody's")
end)

test.case("an evaluation pending when the connection closes gets false and the reason", function()
    local side = make_target()
    local fake = connected(side)
    ---@type {[1]: boolean, [2]: string}[]
    local replies = {}
    side.target:evaluate("return 1", function(ok, body)
        table.insert(replies, {
            ok,
            body
        })
    end)
    fake.peer_closed = true
    side.target:update(0)
    test.assert_deep_eq(replies, {
        {
            false,
            "the console connection closed"
        }
    })
end)

test.case("add_watch sends a watch named by its expression, remove_watch an unwatch, forgetting the watch", function()
    local side = make_target()
    local fake = connected(side)
    side.target:add_watch("app:get_time()")
    test.assert_deep_eq(take_sent(fake), {
        "watch(\"app:get_time()\", function() return app:get_time() end)"
    })
    fake.arriving = frame("watch", "app:get_time()\t3\t0.050\t0.05")
    side.target:update(0)
    test.assert_eq(side.target:get_watches()["app:get_time()"].value, "0.05")
    side.target:remove_watch("app:get_time()")
    test.assert_deep_eq(take_sent(fake), {
        "unwatch(\"app:get_time()\")"
    })
    test.assert_deep_eq(side.target:get_watches(), {})
end)

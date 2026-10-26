local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local ConsoleClient = require("utils.console-client")
local ScenarioDriver = require("app.scenario-driver")
local ScenarioPeerRun = require("app.scenario-peer-run")

---@return TestPeerSocket
local function make_socket()
    ---@class TestPeerSocket: ConsoleSocket
    ---@field buffer string What the peer sent, not yet received
    ---@field peer_closed boolean Once the buffer is empty, `receive` says "closed"
    ---@field receives integer The number of `receive` calls
    ---@field sent string
    local fake = {
        buffer = "",
        peer_closed = false,
        receives = 0,
        sent = ""
    }

    ---@return integer|nil, string|nil
    function fake:connect()
        return 1, nil
    end

    function fake:settimeout()
    end

    ---@param data string
    ---@param i integer|nil
    ---@return integer|nil, string|nil, integer|nil
    function fake:send(data, i)
        self.sent = self.sent .. data:sub(i or 1)
        return #data, nil, nil
    end

    ---@param pattern "*l"|integer
    ---@return string|nil, string|nil, string|nil
    function fake:receive(pattern)
        self.receives = self.receives + 1
        if pattern == "*l" then
            local newline = self.buffer:find("\n", 1, true)
            if newline then
                local line = self.buffer:sub(1, newline - 1)
                self.buffer = self.buffer:sub(newline + 1)
                return line, nil, nil
            end
        elseif type(pattern) == "number" and #self.buffer >= pattern then
            local data = self.buffer:sub(1, pattern)
            self.buffer = self.buffer:sub(pattern + 1)
            return data, nil, nil
        end
        local partial = self.buffer
        self.buffer = ""
        return nil, self.peer_closed and "closed" or "timeout", partial
    end

    function fake:close()
    end

    return fake
end

---@param kind string
---@param body string
---@return string
local function frame(kind, body)
    return string.format("%s %d\n", kind, #body) .. body
end

---@class TestPeerRunWorld
---@field socket TestPeerSocket The peer's end
---@field driver ScenarioDriver
---@field run ScenarioPeerRun Sent to the peer `bob`

---@return TestPeerRunWorld
local function setup()
    local app_mock = mocks.install_app()
    app_mock.params = {
        app_type = "client",
        address = "localhost",
        port = "8080",
        headless = true,
        follow = false
    }
    local socket = make_socket()
    local driver = ScenarioDriver()
    local console = ConsoleClient("9100", nil, function()
        return socket
    end)
    return {
        socket = socket,
        driver = driver,
        run = ScenarioPeerRun(driver, "bob", console, console:request_async("run(\"return 1\")"))
    }
end

---@param world TestPeerRunWorld
local function finish(world)
    lifetime.destroy(world.driver)
end

---@param co thread
---@return "suspended"|"dead"
local function resume(co)
    ---@type boolean, any
    local ok, err = coroutine.resume(co)
    assert(ok, err)
    return coroutine.status(co) == "dead" and "dead" or "suspended"
end

---@param co thread
---@return string The error raised at the next resume
local function failure(co)
    ---@type boolean, any
    local ok, err = coroutine.resume(co)
    assert(not ok, "no error raised")
    return tostring(err)
end

test.suite("ScenarioPeerRun")

test.case("is_done polls the peer's connection and holds once the deferred reply arrived", function()
    local world = setup()
    test.assert_false(world.run:is_done())
    test.assert_true(world.socket.receives > 0, "is_done polled")
    world.socket.buffer = frame("ok", "")
    test.assert_true(world.run:is_done())
    test.assert_true(world.run:is_done(), "and stays done")
    finish(world)
end)

test.case("wait yields frames until the peer's run passed and returns the ok body", function()
    local world = setup()
    ---@type string|nil
    local body
    local co = coroutine.create(function()
        body = world.run:wait()
    end)
    test.assert_eq(resume(co), "suspended")
    test.assert_eq(resume(co), "suspended")
    world.socket.buffer = frame("ok", "Bilbo\t1")
    test.assert_eq(resume(co), "dead")
    test.assert_eq(body, "Bilbo\t1")
    finish(world)
end)

test.case("wait raises at the caller's line with the peer's name and the error body when the peer's run failed", function()
    local world = setup()
    local co = coroutine.create(function()
        world.run:wait()
    end)
    test.assert_eq(resume(co), "suspended")
    world.socket.buffer = frame("error", "peer:1: no TextButton\nstack traceback:")
    local err = failure(co)
    test.assert_true(err:find("test%-scenario%-peer%-run%.lua:%d+: peer bob: peer:1: no TextButton\nstack traceback:$") ~= nil, err)
    finish(world)
end)

test.case("wait raises with the peer's name when the peer's connection closed", function()
    local world = setup()
    world.socket.peer_closed = true
    local co = coroutine.create(function()
        world.run:wait()
    end)
    local err = failure(co)
    test.assert_true(err:find("test%-scenario%-peer%-run%.lua:%d+: peer bob: the console connection closed$") ~= nil, err)
    finish(world)
end)

test.case("wait times out at the caller's line naming the peer", function()
    local world = setup()
    local co = coroutine.create(function()
        world.run:wait(0)
    end)
    local err = failure(co)
    test.assert_true(err:find("test%-scenario%-peer%-run%.lua:%d+: timed out waiting for peer bob$") ~= nil, err)
    finish(world)
end)

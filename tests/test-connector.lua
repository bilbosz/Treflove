local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local ConnectionManager = require("networking.connection-manager")
local Logger = require("utils.logger")

---@class TestConnectorSide
---@field app AppMock
---@field manager ConnectionManager Started, with the callbacks below
---@field thread FakeThread The host thread the connector made
---@field thread_file string|nil The script the connector asked for
---@field channel FakeChannel What the host thread reports on
---@field stop_channel FakeChannel What asks the host thread to end
---@field connected Connection[] Every `on_connect` argument, in order
---@field disconnected Connection[] Every `on_disconnect` argument, in order
---@field now number What `love.timer.getTime` returns

---Runs `fn` with a started connection manager over a fake host thread,
---fake channels and a fake clock, and restores `love.thread` and
---`love.timer` whether `fn` returns or raises
---@param name string
---@param is_server boolean
---@param fn fun(side: TestConnectorSide)
local function connector_case(name, is_server, fn)
    test.case(name, function()
        mocks.ensure_love_thread()
        local app_mock = mocks.install_app({
            is_client = not is_server,
            is_server = is_server
        })
        app_mock.logger = Logger({
            start_time = 0
        }, "test")

        local thread = mocks.make_thread()
        ---@type string|nil
        local thread_file
        ---@type TestConnectorSide|nil
        local side
        local thread_module = love.thread
        local timer_module = love.timer
        ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
        love.thread = {
            newChannel = mocks.make_channel,
            ---@param file string
            ---@return love.Thread
            newThread = function(file)
                thread_file = file
                return thread
            end
        }
        ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
        love.timer = {
            getTime = function()
                return side and side.now or 0
            end
        }

        ---@type boolean, any
        local ok, err = pcall(function()
            local manager = ConnectionManager("localhost", "8080")
            side = {
                app = app_mock,
                manager = manager,
                thread = thread,
                thread_file = nil,
                ---@diagnostic disable-next-line: invisible
                channel = manager._connector._channel --[[@as FakeChannel]] ,
                ---@diagnostic disable-next-line: invisible
                stop_channel = manager._connector._stop_channel --[[@as FakeChannel]] ,
                connected = {},
                disconnected = {},
                now = 0
            }
            manager:start(function(connection)
                table.insert(side.connected, connection)
            end, function(connection)
                table.insert(side.disconnected, connection)
            end)
            side.thread_file = thread_file
            fn(side)
        end)

        love.thread = thread_module
        love.timer = timer_module
        if not ok then
            error(err, 0)
        end
    end)
end

---@param side TestConnectorSide
---@return FakeChannel in_channel
---@return FakeChannel out_channel
local function peer_connects(side)
    local in_channel, out_channel = mocks.make_channel(), mocks.make_channel()
    ---@type ConnectorMessage
    local connected = {
        "a",
        in_channel,
        out_channel
    }
    side.channel:push(connected)
    side.app.update_event:trigger(0.016)
    return in_channel, out_channel
end

---@param side TestConnectorSide
---@param in_channel love.Channel
local function peer_disconnects(side, in_channel)
    ---@type ConnectorMessage
    local disconnected = {
        "d",
        in_channel
    }
    side.channel:push(disconnected)
    side.app.update_event:trigger(0.016)
end

test.suite("Connector")

connector_case("the server starts its host thread with the logger data, the connector's channels, the address and the port", true, function(side)
    test.assert_eq(side.thread_file, "networking/detail/server-host.lua")
    test.assert_eq(#side.thread.starts, 1)
    test.assert_deep_eq(side.thread.starts[1], {
        side.app.logger:get_data(),
        side.channel,
        side.stop_channel,
        "localhost",
        "8080"
    })
    test.assert_true(side.thread:isRunning())
end)

connector_case("the client starts its own host thread", false, function(side)
    test.assert_eq(side.thread_file, "networking/detail/client-host.lua")
    test.assert_eq(#side.thread.starts, 1)
end)

connector_case("a peer the host thread reports becomes a connection over its channels", true, function(side)
    local in_channel, out_channel = peer_connects(side)
    test.assert_eq(#side.connected, 1)
    local connection = side.connected[1]
    test.assert_eq(connection:get_in_channel(), in_channel)
    test.assert_eq(connection:get_out_channel(), out_channel)
    test.assert_true(side.manager:get_connections()[connection])
end)

connector_case("a peer the host thread lost is removed by its in channel and destroyed", true, function(side)
    local in_channel, out_channel = peer_connects(side)
    local connection = side.connected[1]
    peer_disconnects(side, in_channel)
    test.assert_eq(#side.disconnected, 1)
    test.assert_eq(side.disconnected[1], connection)
    test.assert_false(lifetime.alive(connection))
    test.assert_eq(next(side.manager:get_connections()), nil)
    test.assert_eq(out_channel:pop(), false, "the dying connection still asks for the disconnect; the host thread has nobody to deliver it to")
end)

connector_case("a loss reported for a channel of no connection is ignored", true, function(side)
    peer_connects(side)
    peer_disconnects(side, mocks.make_channel())
    test.assert_eq(#side.disconnected, 0)
    test.assert_eq(#side.connected, 1)
end)

connector_case("remove_all disconnects every peer, then stops the host thread and waits for it", true, function(side)
    local _, first_out = peer_connects(side)
    local _, second_out = peer_connects(side)
    side.manager:remove_all()
    test.assert_eq(#side.disconnected, 2)
    test.assert_eq(first_out:pop(), false)
    test.assert_eq(second_out:pop(), false)
    test.assert_eq(next(side.manager:get_connections()), nil)
    test.assert_eq(side.stop_channel:getCount(), 1, "the stop request")
    test.assert_false(side.thread:isRunning(), "waited for")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(side.app.update_event:get_handler(side.manager._connector), nil, "no restart after the stop")
    side.now = 10
    side.app.update_event:trigger(0.016)
    test.assert_eq(#side.thread.starts, 1)
end)

connector_case("stopping an ended host thread asks nothing of it", false, function(side)
    side.thread:finish(nil)
    side.manager:remove_all()
    test.assert_eq(side.stop_channel:getCount(), 0)
end)

test.case("remove_all on a manager that never started has no thread to stop", function()
    mocks.ensure_love_thread()
    mocks.install_app()
    local manager = ConnectionManager("localhost", "8080")
    manager:remove_all()
    test.assert_eq(next(manager:get_connections()), nil)
end)

connector_case("an ended host thread is started again after the retry time, its error logged", false, function(side)
    side.thread:finish("enet: failed to create host")
    side.now = 0.5
    side.app.update_event:trigger(0.016)
    test.assert_eq(#side.thread.starts, 1, "too early to retry")
    side.now = 1
    side.app.update_event:trigger(0.016)
    test.assert_eq(#side.thread.starts, 2)
    test.assert_true(side.thread:isRunning())
    test.assert_deep_eq(side.app.logs[#side.app.logs], {
        "The host thread failed: enet: failed to create host"
    })
end)

connector_case("a running host thread is left alone", true, function(side)
    side.now = 10
    side.app.update_event:trigger(0.016)
    test.assert_eq(#side.thread.starts, 1)
end)

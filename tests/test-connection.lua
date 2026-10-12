local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Connection = require("networking.connection")
local RemoteProcedure = require("networking.remote-procedure")
local lifetime = require("lifetime")

-- An RPC used by the round-trip test. Class name = wire id.
local EchoRp = class("TestEchoRp", RemoteProcedure)

---@param request table
---@return table
function EchoRp:send_response(request)
    return {
        out = request.inp * 2
    }
end

---@param response table
function EchoRp:receive_response(response)
    self.got = response.out
end

---Create a client/server connection pair wired back-to-back with fake
---channels: what the client sends, the server receives, and vice versa.
---@return Connection client_connection
---@return Connection server_connection
local function make_connection_pair()
    local app_mock = mocks.install_app()
    mocks.ensure_love_data()
    local client_to_server = mocks.make_channel()
    local server_to_client = mocks.make_channel()

    app_mock.is_client = true
    local client_connection = Connection(server_to_client, mocks.make_thread(), client_to_server, mocks.make_thread())
    app_mock.is_client = false
    local server_connection = Connection(client_to_server, mocks.make_thread(), server_to_client, mocks.make_thread())

    return client_connection, server_connection
end

test.suite("Connection + RemoteProcedure")

test.case("send_request puts a compressed request on the out channel", function()
    local client_connection = make_connection_pair()
    client_connection:send_request("SomeRp", {
        value = 7
    }, function()
    end)

    local out_channel = client_connection:get_out_channel()
    test.assert_eq(out_channel:getCount(), 1)
end)

test.case("an incoming request is answered by the registered handler", function()
    local client_connection, server_connection = make_connection_pair()
    server_connection:register_request_handler("SomeRp", function(body)
        return {
            doubled = body.value * 2
        }
    end)

    local received
    client_connection:send_request("SomeRp", {
        value = 21
    }, function(body)
        received = body
    end)
    server_connection:on_update()
    client_connection:on_update()

    test.assert_deep_eq(received, {
        doubled = 42
    })
end)

test.case("register_request_handler rejects duplicate ids", function()
    local client_connection = make_connection_pair()
    local handler = function()
        return {}
    end
    client_connection:register_request_handler("Dup", handler)
    test.assert_error(function()
        client_connection:register_request_handler("Dup", handler)
    end)
end)

test.case("full RPC round-trip: request, server handler, client response", function()
    local client_connection, server_connection = make_connection_pair()
    local client_rp = EchoRp(client_connection)
    local _ = EchoRp(server_connection)

    local cb_response
    client_rp:send_request({
        inp = 21
    }, function(response)
        cb_response = response
    end)

    server_connection:on_update()
    client_connection:on_update()

    test.assert_eq(client_rp.got, 42, "receive_response processed the answer")
    test.assert_eq(cb_response.out, 42, "the optional callback also fires")
end)

test.case("responses are matched to requests in FIFO order", function()
    local client_connection, server_connection = make_connection_pair()
    server_connection:register_request_handler("OrderRp", function(body)
        return {
            id = body.id
        }
    end)

    local received = {}
    client_connection:send_request("OrderRp", {
        id = "a"
    }, function(body)
        table.insert(received, body.id)
    end)
    client_connection:send_request("OrderRp", {
        id = "b"
    }, function(body)
        table.insert(received, body.id)
    end)

    server_connection:on_update()
    client_connection:on_update()

    test.assert_deep_eq(received, {
        "a",
        "b"
    })
end)

test.case("release frees channels and threads", function()
    local client_connection = make_connection_pair()
    local in_channel = client_connection:get_in_channel() --[[@as FakeChannel]]
    local out_channel = client_connection:get_out_channel() --[[@as FakeChannel]]
    client_connection:release()
    test.assert_true(in_channel._released)
    test.assert_true(out_channel._released)
end)

test.case("a second release of a procedure is harmless", function()
    local client_connection = make_connection_pair()
    local rp = EchoRp(client_connection)
    rp:release()
    rp:release()
    test.assert_eq(client_connection._requests_handlers["TestEchoRp"], nil, "the handler is gone")
    test.assert_true(lifetime.alive(rp), "release is the body, not the death")
end)

-- The order of a connection's death (lua-lifetime docs/02-semantics.md,
-- "Cascading death"): `log` records each release and each handler a
-- dying procedure unregisters from the dying connection.
local log = {}

local LoggingConnection = class("TestLoggingConnection", Connection)

function LoggingConnection:release(reason)
    table.insert(log, "Connection:release(" .. tostring(reason) .. ")")
    Connection.release(self, reason)
end

---@param id string
function LoggingConnection:unregister_request_handler(id)
    table.insert(log, "  unregister " .. id)
    Connection.unregister_request_handler(self, id)
end

---@param name string
---@return table
local function make_logging_rp_class(name)
    local cls = class(name, RemoteProcedure)
    function cls:release(reason)
        table.insert(log, name .. ":release(" .. tostring(reason) .. ")")
        RemoteProcedure.release(self, reason)
    end
    return cls
end

local LogRpA = make_logging_rp_class("TestLogRpA")
local LogRpB = make_logging_rp_class("TestLogRpB")
local LogRpC = make_logging_rp_class("TestLogRpC")

test.case("destroying a connection releases it first, then its procedures newest first", function()
    mocks.install_app()
    mocks.ensure_love_data()
    local in_channel, out_channel = mocks.make_channel(), mocks.make_channel()
    local connection = LoggingConnection(in_channel, mocks.make_thread(), out_channel, mocks.make_thread())
    -- `RpX(connection) @ connection`
    local a = lifetime.attach(LogRpA(connection), false, connection)
    local b = lifetime.attach(LogRpB(connection), false, connection)
    local c = lifetime.attach(LogRpC(connection), false, connection)
    log = {}

    lifetime.destroy(connection)

    -- The root's own body first, with every dependent alive; then its
    -- dependents, most recently attached first, each reaching the
    -- connection, which is dying, not dead, until the last one is done.
    test.assert_deep_eq(log, {
        "Connection:release(destroy)",
        "TestLogRpC:release(anchor)",
        "  unregister TestLogRpC",
        "TestLogRpB:release(anchor)",
        "  unregister TestLogRpB",
        "TestLogRpA:release(anchor)",
        "  unregister TestLogRpA"
    })
    test.assert_false(lifetime.alive(connection))
    test.assert_false(lifetime.alive(a))
    test.assert_false(lifetime.alive(b))
    test.assert_false(lifetime.alive(c))
    test.assert_true(in_channel._released)
    test.assert_true(out_channel._released)
end)

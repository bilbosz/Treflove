local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Connection = require("networking.connection")
local RemoteProcedure = require("networking.remote-procedure")

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

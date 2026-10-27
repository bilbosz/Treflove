local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Connection = require("networking.connection")
local RemoteProcedure = require("networking.remote-procedure")

---@class TestEchoRequest
---@field inp number

---@class TestEchoResponse
---@field out number

---@class TestEchoRp: RemoteProcedure
---@field got number|nil The `out` of the last response received
---@overload fun(connection: Connection, dont_start: boolean|nil): TestEchoRp
local EchoRp = class("TestEchoRp", RemoteProcedure)

---@param request TestEchoRequest
---@return TestEchoResponse
function EchoRp:send_response(request)
    return {
        out = request.inp * 2
    }
end

---@param response TestEchoResponse
function EchoRp:receive_response(response)
    self.got = response.out
end

---@return Connection client_connection
---@return Connection server_connection
local function make_connection_pair()
    local app_mock = mocks.install_app()
    mocks.ensure_love_data()
    local client_to_server = mocks.make_channel()
    local server_to_client = mocks.make_channel()

    app_mock.is_client = true
    local client_connection = Connection(server_to_client, client_to_server)
    app_mock.is_client = false
    local server_connection = Connection(client_to_server, server_to_client)

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
    ---@param body {value: number}
    ---@return {doubled: number}
    local function double(body)
        return {
            doubled = body.value * 2
        }
    end
    server_connection:register_request_handler("SomeRp", double)

    ---@type {doubled: number}|nil
    local received
    ---@param body {doubled: number}
    local function receive(body)
        received = body
    end
    client_connection:send_request("SomeRp", {
        value = 21
    }, receive)
    server_connection:on_update()
    client_connection:on_update()

    test.assert_deep_eq(received, {
        doubled = 42
    })
end)

test.case("a request for an unknown procedure is logged and answered with a refusal naming it, and the peer stays connected", function()
    local client_connection, server_connection = make_connection_pair()
    ---@type ResponseBody|nil
    local received
    ---@param body ResponseBody
    local function receive(body)
        received = body
    end
    client_connection:send_request("MissingRp", {
        value = 1
    }, receive)
    server_connection:on_update()
    local out_channel = server_connection:get_out_channel()
    test.assert_eq(out_channel:getCount(), 1, "the refusal alone, no disconnect request")
    test.assert_deep_eq(app.logs[#app.logs], {
        "A request for the unknown procedure \"MissingRp\" ignored"
    })
    client_connection:on_update()
    test.assert_deep_eq(received, {
        success = false,
        error = "Unknown procedure \"MissingRp\""
    })
    test.assert_eq(app.update_event:get_handler(server_connection), Connection.on_update)
end)

test.case("the sender's queue stays in step after a request for an unknown procedure", function()
    local client_connection, server_connection = make_connection_pair()
    ---@param body {value: number}
    ---@return {doubled: number}
    local function double(body)
        return {
            doubled = body.value * 2
        }
    end
    server_connection:register_request_handler("SomeRp", double)

    ---@type ResponseBody[]
    local received = {}
    ---@param body ResponseBody
    local function receive(body)
        table.insert(received, body)
    end
    client_connection:send_request("MissingRp", {}, receive)
    client_connection:send_request("SomeRp", {
        value = 21
    }, receive)
    server_connection:on_update()
    client_connection:on_update()

    test.assert_deep_eq(received, {
        {
            success = false,
            error = "Unknown procedure \"MissingRp\""
        },
        {
            doubled = 42
        }
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

    ---@type TestEchoResponse|nil
    local cb_response
    ---@param response TestEchoResponse
    local function receive(response)
        cb_response = response
    end
    client_rp:send_request({
        inp = 21
    }, receive)

    server_connection:on_update()
    client_connection:on_update()

    test.assert_eq(client_rp.got, 42, "receive_response processed the answer")
    test.assert_eq(assert(cb_response).out, 42, "the optional callback also fires")
end)

test.case("responses are matched to requests in FIFO order", function()
    local client_connection, server_connection = make_connection_pair()
    ---@param body {id: string}
    ---@return {id: string}
    local function echo_id(body)
        return {
            id = body.id
        }
    end
    server_connection:register_request_handler("OrderRp", echo_id)

    ---@type string[]
    local received = {}
    ---@param body {id: string}
    local function receive(body)
        table.insert(received, body.id)
    end
    client_connection:send_request("OrderRp", {
        id = "a"
    }, receive)
    client_connection:send_request("OrderRp", {
        id = "b"
    }, receive)

    server_connection:on_update()
    client_connection:on_update()

    test.assert_deep_eq(received, {
        "a",
        "b"
    })
end)

test.case("destroying a connection asks the host thread to disconnect the peer, releases its channels and unregisters it from the update event", function()
    local client_connection = make_connection_pair()
    local in_channel = client_connection:get_in_channel() --[[@as FakeChannel]]
    local out_channel = client_connection:get_out_channel() --[[@as FakeChannel]]
    test.assert_eq(app.update_event:get_handler(client_connection), Connection.on_update)
    lifetime.destroy(client_connection)
    test.assert_eq(out_channel:pop(), false, "the disconnect request is the last thing on the out channel")
    test.assert_eq(out_channel:getCount(), 0)
    test.assert_true(in_channel._released)
    test.assert_true(out_channel._released)
    test.assert_eq(app.update_event:get_handler(client_connection), nil)
    test.assert_false(lifetime.alive(client_connection))
end)

test.case("procedures anchored to a connection stop with it, newest first, after its own release", function()
    local client_connection = make_connection_pair()
    local log = {}
    local unregister = Connection.unregister_request_handler
    client_connection.unregister_request_handler = function(self, id)
        table.insert(log, "unregister " .. id)
        return unregister(self, id)
    end
    local release = Connection.release
    client_connection.release = function(self, reason)
        table.insert(log, "Connection:release(" .. reason .. ")")
        return release(self, reason)
    end
    local first = EchoRp(client_connection):attach_lifetime(client_connection)
    ---@class TestSecondRp: RemoteProcedure
    ---@overload fun(connection: Connection, dont_start: boolean|nil): TestSecondRp
    local Second = class("TestSecondRp", RemoteProcedure)
    local second = Second(client_connection):attach_lifetime(client_connection)

    lifetime.destroy(client_connection)
    test.assert_deep_eq(log, {
        "Connection:release(destroy)",
        "unregister TestSecondRp",
        "unregister TestEchoRp"
    })
    test.assert_false(lifetime.alive(first))
    test.assert_false(lifetime.alive(second))
end)

local Consts = require("app.consts")

---@class RequestBody The base of every remote procedure's request class

---@class ResponseBody The base of every remote procedure's response class

---@class UnknownProcedureResponse: ResponseBody The answer to a request for a procedure the receiver has no handler for
---@field public success false
---@field public error string Names the procedure

---@alias ConnectionSource
---| "c" # The client
---| "s" # The server

---@class Request
---@field public source ConnectionSource The side that sent the request
---@field public id string The remote procedure's class name
---@field public body RequestBody

---@class Response
---@field public source ConnectionSource The side that sent the request, so the response goes back to it
---@field public id string The remote procedure's class name
---@field public body ResponseBody

---@alias ConnectionMessage Request|Response What the channels carry, serialized and compressed

---@alias ConnectionOutgoing string|false What the out channel carries: a serialized and compressed message, or `false`, which asks the host thread to disconnect the peer

---@alias ConnectionResponseHandler fun(body: ResponseBody) Processes the body of a received response
---@alias ConnectionRequestHandler fun(body: RequestBody): ResponseBody Handles a request body and returns the response body

---@class Connection: Object
---@field private _queue ConnectionResponseHandler[] Handlers awaiting responses, in request order
---@field private _in_channel love.Channel The messages the host thread received from the peer
---@field private _out_channel love.Channel The messages for the host thread to send to the peer
---@field private _source ConnectionSource
---@field private _requests_handlers table<string, ConnectionRequestHandler>
local Connection = class("Connection")

---@param message ConnectionMessage
---@return string
local function _compress(message)
    return love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(message)) --[[@as string]]
end

---@param payload string
---@return ConnectionMessage
local function _decompress(payload)
    local serialized = love.data.decompress("string", Consts.NETWORK_COMPRESSION, payload) --[[@as string]]
    return table.from_string(serialized) --[[@as ConnectionMessage]]
end

---@param id string
---@return UnknownProcedureResponse
local function _refuse_unknown_procedure(id)
    app:log(string.format("A request for the unknown procedure %q ignored", id))
    return {
        success = false,
        error = string.format("Unknown procedure %q", id)
    }
end

---@param in_channel love.Channel
---@param out_channel love.Channel
function Connection:init(in_channel, out_channel)
    self._in_channel = in_channel
    self._out_channel = out_channel
    self._queue = {}
    self._source = app.is_client and "c" or "s"
    self._requests_handlers = {}

    app.update_event:register(self, self.on_update)
end

---@param id string
---@param body RequestBody
---@param response_handler ConnectionResponseHandler
function Connection:send_request(id, body, response_handler)
    assert_type(body, "table")
    assert_type(response_handler, "function")

    ---@type Request
    local request = {
        source = self._source,
        id = id,
        body = body
    }
    table.insert(self._queue, response_handler)
    self._out_channel:push(_compress(request))
end

---@param id string
---@param request_handler ConnectionRequestHandler
function Connection:register_request_handler(id, request_handler)
    assert(not self._requests_handlers[id])
    self._requests_handlers[id] = request_handler
end

---@param id string
function Connection:unregister_request_handler(id)
    self._requests_handlers[id] = nil
end

---@return love.Channel
function Connection:get_in_channel()
    return self._in_channel
end

---@return love.Channel
function Connection:get_out_channel()
    return self._out_channel
end

function Connection:on_update()
    while true do
        local payload = self._in_channel:pop()
        if not payload then
            break
        end
        local message = _decompress(payload)
        if message.source == self._source then
            self:_handle_response(message --[[@as Response]] )
        else
            self:_send_response(message --[[@as Request]] )
        end
    end
end

---@param reason lifetime.Reason
function Connection:release(reason)
    app.update_event:unregister(self)
    self._out_channel:push(false)
    self._in_channel:release()
    self._out_channel:release()
end

---@private
---@param message Response
function Connection:_handle_response(message)
    table.remove(self._queue, 1)(message.body)
end

---@private
---@param request Request
function Connection:_send_response(request)
    assert_type(request, "table")
    assert_type(request.body, "table")
    assert_type(request.id, "string")

    local handler = self._requests_handlers[request.id]
    ---@type ResponseBody
    local body
    if handler then
        body = handler(request.body)
    else
        body = _refuse_unknown_procedure(request.id)
    end
    assert_type(body, "table")
    ---@type Response
    local response = {
        source = request.source,
        id = request.id,
        body = body
    }
    self._out_channel:push(_compress(response))
end

return Connection

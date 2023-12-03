local Consts = require("app.consts")
local UpdateEventListener = require("events.update-event").Listener

---@class Connection: UpdateEventListener
local Connection = class("Connection", UpdateEventListener)

---@param message table
---@return string
local function _compress(message)
    return love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(message))
end

---@param payload string
---@return table
local function _decompress(payload)
    return table.from_string(love.data.decompress("string", Consts.NETWORK_COMPRESSION, payload))
end

---@param in_channel LoveChannel
---@param in_thread LoveThread
---@param out_channel LoveChannel
---@param out_thread LoveThread
---@return void
function Connection:init(in_channel, in_thread, out_channel, out_thread)
    self._in_channel = in_channel
    self._in_thread = in_thread
    self._out_channel = out_channel
    self._out_thread = out_thread
    self._queue = {}
    self._source = app.is_client and "c" or "s"
    self._requests_handlers = {}

    app.update_event_manager:register_listener(self)
end

---@param id string
---@param body table
---@param response_handler fun(body:table):void
---@return void
function Connection:send_request(id, body, response_handler)
    assert_type(body, "table")
    assert_type(response_handler, "function")

    local request = {
        source = self._source,
        id = id,
        body = body
    }
    table.insert(self._queue, response_handler)
    self._out_channel:push(_compress(request))
end

---@param id string
---@param response_handler fun(body:table):void
---@return void
function Connection:register_request_handler(id, response_handler)
    assert(not self._requests_handlers[id])
    self._requests_handlers[id] = response_handler
end

---@param id string
---@return void
function Connection:unregister_request_handler(id)
    self._requests_handlers[id] = nil
end

---@return LoveChannel
function Connection:get_in_channel()
    return self._in_channel
end

---@return LoveChannel
function Connection:get_out_channel()
    return self._out_channel
end

---@return void
function Connection:on_update()
    while true do
        local payload = self._in_channel:pop()
        if not payload then
            break
        end
        local message = _decompress(payload)
        if message.source == self._source then
            self:_handle_response(message)
        else
            self:_send_response(message)
        end
    end
end

---@return void
function Connection:release()
    app.update_event_manager:unregister_listener(self)
    self._in_thread:release()
    self._in_channel:release()
    self._out_thread:release()
    self._out_channel:release()
end

---@private
---@param message table
---@return string
function Connection:_handle_response(message)
    return table.remove(self._queue, 1)(message.body)
end

---@private
---@param request table
---@return table
function Connection:_send_response(request)
    assert_type(request, "table")
    assert_type(request.body, "table")
    assert_type(request.id, "string")

    local body = self._requests_handlers[request.id](request.body)
    assert_type(body, "table")
    local response = {
        source = request.source,
        id = request.id,
        body = body
    }
    self._out_channel:push(_compress(response))
end

return Connection

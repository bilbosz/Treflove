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

---@param inChannel LoveChannel
---@param inThread LoveThread
---@param outChannel LoveChannel
---@param outThread LoveThread
---@return void
function Connection:init(inChannel, inThread, outChannel, outThread)
    self.inChannel = inChannel
    self.inThread = inThread
    self.outChannel = outChannel
    self.outThread = outThread
    self.queue = {}
    self.source = app.is_client and "c" or "s"
    self.requestHandlers = {}

    app.update_event_manager:register_listener(self)
end

---@param id string
---@param body table
---@param responseHandler fun(body:table):void
---@return void
function Connection:send_request(id, body, responseHandler)
    assert_type(body, "table")
    assert_type(responseHandler, "function")

    local request = {
        source = self.source,
        id = id,
        body = body
    }
    table.insert(self.queue, responseHandler)
    self.outChannel:push(_compress(request))
end

---@param id string
---@param responseHandler fun(body:table):void
---@return void
function Connection:register_request_handler(id, responseHandler)
    assert(not self.requestHandlers[id])
    self.requestHandlers[id] = responseHandler
end

---@param id string
---@return void
function Connection:unregister_request_handler(id)
    self.requestHandlers[id] = nil
end

---@return LoveChannel
function Connection:get_in_channel()
    return self.inChannel
end

---@return LoveChannel
function Connection:get_out_channel()
    return self.outChannel
end

---@return void
function Connection:on_update()
    while true do
        local payload = self.inChannel:pop()
        if not payload then
            break
        end
        local message = _decompress(payload)
        if message.source == self.source then
            self:_handle_response(message)
        else
            self:_send_response(message)
        end
    end
end

---@return void
function Connection:release()
    app.update_event_manager:unregister_listener(self)
    self.inThread:release()
    self.inChannel:release()
    self.outThread:release()
    self.outChannel:release()
end

---@private
---@param message table
---@return string
function Connection:_handle_response(message)
    return table.remove(self.queue, 1)(message.body)
end

---@private
---@param request table
---@return table
function Connection:_send_response(request)
    assert_type(request, "table")
    assert_type(request.body, "table")
    assert_type(request.id, "string")

    local body = self.requestHandlers[request.id](request.body)
    assert_type(body, "table")
    local response = {
        source = request.source,
        id = request.id,
        body = body
    }
    self.outChannel:push(_compress(response))
end

return Connection

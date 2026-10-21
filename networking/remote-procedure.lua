---@alias RemoteProcedureCallback fun(response: ResponseBody) Called with the response body after `receive_response`
---@class RemoteProcedure: Object
---@field private _id string
---@field private _connection Connection
local RemoteProcedure = class("RemoteProcedure")

---@param connection Connection
---@param dont_start boolean|nil
function RemoteProcedure:init(connection, dont_start)
    assert(connection)
    self._connection = connection
    self._id = get_class_name_of(self)

    if not dont_start then
        self:start()
    end
end

function RemoteProcedure:start()
    self._connection:register_request_handler(self._id, function(request)
        return self:send_response(request)
    end)
end

function RemoteProcedure:stop()
    self._connection:unregister_request_handler(self._id)
end

---@param request RequestBody
---@param cb RemoteProcedureCallback|nil
function RemoteProcedure:send_request(request, cb)
    self._connection:send_request(self._id, request, function(response)
        self:receive_response(response)
        if cb then
            cb(response)
        end
    end)
end

---@param request RequestBody
---@return ResponseBody
function RemoteProcedure:send_response(request)
    return abstract()
end

---@param response ResponseBody
function RemoteProcedure:receive_response(response)
    abstract()
end

---@param reason lifetime.Reason
function RemoteProcedure:release(reason)
    self:stop()
end

return RemoteProcedure

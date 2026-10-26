local socket = require("socket")

---@class ConsoleStream The part of a connected LuaSocket TCP object both ends of the console use
---@field settimeout fun(self: ConsoleStream, value: number|nil)
---@field send fun(self: ConsoleStream, data: string, i: integer|nil): integer|nil, string|nil, integer|nil The index of the last byte sent, or `nil`, the error and the index of the last byte sent before it
---@field receive fun(self: ConsoleStream, pattern: "*l"|integer): string|nil, string|nil, string|nil The data, or `nil`, the error and what was received before it
---@field close fun(self: ConsoleStream)

---@class ConsoleSocket: ConsoleStream The client's, connected by itself
---@field connect fun(self: ConsoleSocket, address: string, port: integer): integer|nil, string|nil

---@alias ConsoleSocketFactory fun(): ConsoleSocket
---@alias ConsoleFrameHandler fun(kind: string, body: string)

---@class ConsoleRequest: Object
---@field private _done boolean
---@field private _ok boolean
---@field private _body string
---@field private _failure string|nil Why the request got no reply
local ConsoleRequest = class("ConsoleRequest")

function ConsoleRequest:init()
    self._done = false
    self._ok = false
    self._body = ""
    self._failure = nil
end

---@return boolean done Its reply came, or the connection closed before it
function ConsoleRequest:is_done()
    return self._done
end

---@return boolean ok `false` for an `error` reply
---@return string body The chunk's results, or the error with its traceback
function ConsoleRequest:get_result()
    if not self._done then
        error("the console request has no reply yet", 2)
    end
    if self._failure then
        error(self._failure, 0)
    end
    return self._ok, self._body
end

---@package
---@param ok boolean
---@param body string
function ConsoleRequest:_complete(ok, body)
    self._done, self._ok, self._body = true, ok, body
end

---@package
---@param failure string
function ConsoleRequest:_fail(failure)
    self._done, self._failure = true, failure
end

---@class ConsoleClient: Object
---@field DEFAULT_TIMEOUT number Seconds a request waits for its reply
---@field private _socket ConsoleSocket
---@field private _pending ConsoleRequest[] Sent, awaiting their replies, oldest first
---@field private _frame_handler ConsoleFrameHandler|nil
---@field private _kind string|nil The kind of the frame whose body is being received
---@field private _length integer The length of that body
---@field private _partial string What has been received of the header line or the body so far
---@field private _closed boolean
local ConsoleClient = class("ConsoleClient")

ConsoleClient.DEFAULT_TIMEOUT = 10

---@return ConsoleSocket
local function _make_tcp()
    -- A master until `connect` makes it a client; the annotations also lack the partial results
    return assert(socket.tcp()) --[[@as ConsoleSocket]]
end

---@param deadline number
---@return number
local function _remaining(deadline)
    return math.max(0, deadline - socket.gettime())
end

---@param port string
---@param host string|nil Defaults to 127.0.0.1
---@param tcp ConsoleSocketFactory|nil Defaults to LuaSocket's `socket.tcp`
function ConsoleClient:init(port, host, tcp)
    host = host or "127.0.0.1"
    self._socket = (tcp or _make_tcp)()
    self._frame_handler = nil
    self._kind = nil
    self._length = 0
    self._partial = ""
    self._closed = false
    self._pending = {}
    self._socket:settimeout(ConsoleClient.DEFAULT_TIMEOUT)
    local ok, err = self._socket:connect(host, assert(tonumber(port), "the port is a number"))
    if not ok then
        self:close()
        error(string.format("cannot connect to the console at %s:%s: %s", host, port, tostring(err)), 0)
    end
end

---@param chunk string
---@return ConsoleRequest request Done once `poll` received its reply
function ConsoleClient:request_async(chunk)
    return self:_send_request(chunk, socket.gettime() + ConsoleClient.DEFAULT_TIMEOUT)
end

---@param chunk string
---@param timeout number|nil Seconds, defaults to `DEFAULT_TIMEOUT`
---@return boolean ok `false` for an `error` reply
---@return string body The chunk's results, or the error with its traceback
function ConsoleClient:request(chunk, timeout)
    local deadline = socket.gettime() + (timeout or ConsoleClient.DEFAULT_TIMEOUT)
    local request = self:_send_request(chunk, deadline)
    self:_receive_until(deadline, request)
    if not request:is_done() then
        error("the console request timed out", 0)
    end
    return request:get_result()
end

---@param fn ConsoleFrameHandler
function ConsoleClient:set_frame_handler(fn)
    assert_type(fn, "function")
    self._frame_handler = fn
end

---@param timeout number|nil Seconds, defaults to 0
---@return boolean open `false` once the connection closed
function ConsoleClient:poll(timeout)
    self:_receive_until(socket.gettime() + (timeout or 0), nil)
    return not self._closed
end

function ConsoleClient:close()
    if not self._closed then
        self._closed = true
        self._socket:close()
        local pending = self._pending
        self._pending = {}
        for _, request in ipairs(pending) do
            request:_fail("the console connection closed")
        end
    end
end

---@private
---@param chunk string
---@param deadline number
---@return ConsoleRequest
function ConsoleClient:_send_request(chunk, deadline)
    assert_type(chunk, "string")
    self:_send_frame("eval", chunk, deadline)
    local request = ConsoleRequest()
    table.insert(self._pending, request)
    return request
end

---@private
---@param deadline number
---@param request ConsoleRequest|nil Stops once it is done
function ConsoleClient:_receive_until(deadline, request)
    while not self._closed and not (request and request:is_done()) do
        local kind, body = self:_receive_frame(deadline)
        if not kind or not body then
            return
        end
        self:_dispatch(kind, body)
    end
end

---@private
---@param kind string
---@param body string
function ConsoleClient:_dispatch(kind, body)
    if (kind == "ok" or kind == "error") and self._pending[1] then
        table.remove(self._pending, 1):_complete(kind == "ok", body)
    elseif self._frame_handler then
        self._frame_handler(kind, body)
    end
end

---@private
---@param kind string
---@param body string
---@param deadline number
function ConsoleClient:_send_frame(kind, body, deadline)
    if self._closed then
        error("the console connection closed", 0)
    end
    local data = string.format("%s %d\n", kind, #body) .. body
    local i = 1
    while i <= #data do
        self._socket:settimeout(_remaining(deadline))
        local last, err, partial_last = self._socket:send(data, i)
        if last then
            i = last + 1
        elseif err == "timeout" and socket.gettime() < deadline then
            i = partial_last and partial_last + 1 or i
        else
            if err ~= "timeout" then
                self:close()
            end
            error(self._closed and "the console connection closed" or "the console request timed out", 0)
        end
    end
end

---@private
---@param pattern "*l"|integer A line, or the number of bytes the whole data has
---@param deadline number
---@return string|nil data `nil` on a timeout or once the connection closed
function ConsoleClient:_receive(pattern, deadline)
    local complete = pattern ~= "*l" and #self._partial == pattern
    while not complete do
        local wanted = pattern == "*l" and pattern or pattern - #self._partial
        self._socket:settimeout(_remaining(deadline))
        local data, err, partial = self._socket:receive(wanted)
        self._partial = self._partial .. (data or partial or "")
        complete = data ~= nil
        if not complete and err ~= "timeout" then
            self:close()
            return nil
        elseif not complete and socket.gettime() >= deadline then
            return nil
        end
    end
    local data = self._partial
    self._partial = ""
    return data
end

---@private
---@param deadline number
---@return string|nil kind `nil` on a timeout or once the connection closed
---@return string|nil body
function ConsoleClient:_receive_frame(deadline)
    if not self._kind then
        local line = self:_receive("*l", deadline)
        if not line then
            return nil, nil
        end
        local kind, length = line:match("^(%l+) (%d+)$")
        if not kind then
            self:close()
            error(string.format("malformed console frame header %q", line), 0)
        end
        self._kind, self._length = kind, assert(tonumber(length))
    end
    local body = self:_receive(self._length, deadline)
    if not body then
        return nil, nil
    end
    local kind = self._kind
    self._kind = nil
    return kind, body
end

return ConsoleClient

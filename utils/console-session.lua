local socket = require("socket")
local ConsoleClient = require("utils.console-client")

---@class ConsoleSessionMode
---@field chunk string|nil The chunk to evaluate; unused with `watch`
---@field follow boolean After the reply, output every async frame until the connection closes
---@field watch string|nil An expression to watch under its own text; follows

---@class ConsoleCliOptions: ConsoleSessionMode
---@field host string|nil
---@field port string

---@alias ConsoleSessionOutput fun(line: string, is_error: boolean) A line to print, to the error output when `is_error`

---@class ConsoleSession: Object
---@field EXIT_OK integer
---@field EXIT_ERROR integer
---@field EXIT_FAILURE integer
---@field POLL_SLICE number Seconds of one poll within a step, the longest a step overruns its reply
---@field private _client ConsoleClient
---@field private _chunk string
---@field private _follow boolean
---@field private _output ConsoleSessionOutput
---@field private _started boolean
---@field private _request ConsoleRequest|nil From `start` until its reply is output
---@field private _reply_deadline number
---@field private _exit_code integer|nil Once finished
local ConsoleSession = class("ConsoleSession")

ConsoleSession.EXIT_OK = 0
ConsoleSession.EXIT_ERROR = 1
ConsoleSession.EXIT_FAILURE = 2
ConsoleSession.POLL_SLICE = 0.01

---@param expression string
---@return string chunk Watches the expression under its own text
function ConsoleSession.watch_chunk(expression)
    return string.format("watch(%q, function()\nreturn %s\nend)", expression, expression)
end

---@param args string[] The arguments of `tools/console.lua`, from `arg[1]` on
---@return ConsoleCliOptions|nil options `nil` for a usage error
function ConsoleSession.parse(args)
    ---@type string|nil, string|nil, boolean
    local host, watch, follow = nil, nil, false
    ---@type string[]
    local positional = {}
    local i = 1
    while args[i] do
        local argument, value = args[i], args[i + 1]
        if argument == "--follow" then
            if follow then
                return nil
            end
            follow = true
            i = i + 1
        elseif argument == "--host" then
            if host or not value then
                return nil
            end
            host = value
            i = i + 2
        elseif argument == "--watch" then
            if watch or not value then
                return nil
            end
            watch = value
            i = i + 2
        else
            table.insert(positional, argument)
            i = i + 1
        end
    end
    ---@type string|nil, string|nil
    local port, chunk = positional[1], positional[2]
    local number = tonumber(port)
    if not port or not string.match(port, "^%d+$") or not number or number < 1 or number > 65535 or positional[3] then
        return nil
    end
    if watch and chunk then
        return nil
    end
    return {
        host = host,
        port = port,
        chunk = chunk ~= "-" and chunk or nil,
        follow = follow,
        watch = watch
    }
end

---@param address string
---@param port string
---@param mode ConsoleSessionMode With a chunk, or a watch
---@param output ConsoleSessionOutput
---@param tcp ConsoleSocketFactory|nil Defaults to LuaSocket's `socket.tcp`
function ConsoleSession:init(address, port, mode, output, tcp)
    assert_type(output, "function")
    self._chunk = mode.watch and ConsoleSession.watch_chunk(mode.watch) or assert(mode.chunk, "a chunk or a watch")
    self._follow = mode.follow or mode.watch ~= nil
    self._output = output
    self._started = false
    self._request = nil
    self._reply_deadline = 0
    self._exit_code = nil
    self._client = ConsoleClient(port, address, tcp)
    if self._follow then
        self._client:set_frame_handler(function(_, body)
            self._output(body, false)
        end)
    end
end

function ConsoleSession:start()
    assert(not self._started, "the session started already")
    self._started = true
    ---@type boolean, ConsoleRequest|string
    local sent, request = pcall(self._client.request_async, self._client, self._chunk)
    if not sent or type(request) == "string" then
        self:_fail(tostring(request))
        return
    end
    self._request = request
    self._reply_deadline = socket.gettime() + ConsoleClient.DEFAULT_TIMEOUT
end

---@param timeout number Seconds
---@return boolean running `false` once finished
function ConsoleSession:step(timeout)
    assert(self._started, "the session is not started")
    local deadline = socket.gettime() + timeout
    while not self._exit_code do
        ---@type boolean, boolean|string
        local polled, open = pcall(self._client.poll, self._client, math.min(ConsoleSession.POLL_SLICE, math.max(0, deadline - socket.gettime())))
        self:_settle(open == true, not polled and tostring(open) or nil)
        if socket.gettime() >= deadline then
            break
        end
    end
    return not self._exit_code
end

---@return integer exit_code `EXIT_FAILURE` while not finished
function ConsoleSession:get_exit_code()
    return self._exit_code or ConsoleSession.EXIT_FAILURE
end

function ConsoleSession:close()
    self._client:close()
end

---@private
---@param open boolean
---@param failure string|nil Why the poll raised
function ConsoleSession:_settle(open, failure)
    local request = self._request
    if request and request:is_done() then
        ---@type boolean, boolean|string, string|nil
        local replied, ok, body = pcall(request.get_result, request)
        if replied and body then
            self._request = nil
            self:_output_reply(ok == true, body)
        else
            self:_fail(failure or tostring(ok))
        end
    elseif request and not failure and socket.gettime() >= self._reply_deadline then
        self:_fail("the console request timed out")
    end
    if self._exit_code then
        return
    elseif failure then
        self:_fail(failure)
    elseif not self._request and not open then
        self:_finish(ConsoleSession.EXIT_OK)
    end
end

---@private
---@param ok boolean
---@param body string
function ConsoleSession:_output_reply(ok, body)
    if not ok then
        self._output(body, true)
        self:_finish(ConsoleSession.EXIT_ERROR)
    else
        if body ~= "" then
            self._output(body, false)
        end
        if not self._follow then
            self:_finish(ConsoleSession.EXIT_OK)
        end
    end
end

---@private
---@param message string
function ConsoleSession:_fail(message)
    self._output(message, true)
    self:_finish(ConsoleSession.EXIT_FAILURE)
end

---@private
---@param exit_code integer
function ConsoleSession:_finish(exit_code)
    self._exit_code = exit_code
    self._client:close()
end

return ConsoleSession

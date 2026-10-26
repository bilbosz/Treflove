local Consts = require("app.consts")
local ConsoleClient = require("utils.console-client")

---@alias MonitorTargetState "connecting"|"connected"|"closed"
---@alias MonitorReplyHandler fun(ok: boolean, body: string)

---@class MonitorWatch
---@field value string What the target's last evaluation serialized to
---@field frame integer The target's frame of that evaluation
---@field time number The target's app time of that evaluation

---@class MonitorEvaluation
---@field request ConsoleRequest
---@field on_reply MonitorReplyHandler

---@class MonitorTarget: Object
---@field private _name string
---@field private _host string
---@field private _port string
---@field private _tcp ConsoleSocketFactory|nil
---@field private _client ConsoleClient|nil While connected
---@field private _state MonitorTargetState
---@field private _next_attempt number The app time of the next connection attempt
---@field private _watches table<string, MonitorWatch>
---@field private _log string[] Oldest first
---@field private _log_end integer The lines appended so far, the last one's number
---@field private _evaluations MonitorEvaluation[] Awaiting their replies, oldest first
---@field private _revision integer
local MonitorTarget = class("MonitorTarget")

---@param name string
---@param host string
---@param port string The target's console port
---@param tcp ConsoleSocketFactory|nil Defaults to LuaSocket's `socket.tcp`
function MonitorTarget:init(name, host, port, tcp)
    assert_type(name, "string")
    assert_type(host, "string")
    assert_type(port, "string")
    self._name = name
    self._host = host
    self._port = port
    self._tcp = tcp
    self._client = nil
    self._state = "connecting"
    self._next_attempt = app:get_time()
    self._watches = {}
    self._log = {}
    self._log_end = 0
    self._evaluations = {}
    self._revision = 0
end

---@param reason lifetime.Reason
function MonitorTarget:release(reason)
    if reason == "unreachable" or reason == "exit" then
        return
    end
    if self._client then
        self._client:close()
    end
end

---@return string
function MonitorTarget:get_name()
    return self._name
end

---@return string
function MonitorTarget:get_host()
    return self._host
end

---@return string
function MonitorTarget:get_port()
    return self._port
end

---@return MonitorTargetState
function MonitorTarget:get_state()
    return self._state
end

---@return integer revision Changes whenever the state, the watches or the log do
function MonitorTarget:get_revision()
    return self._revision
end

---@return table<string, MonitorWatch> watches By name, as the target last reported them
function MonitorTarget:get_watches()
    return table.copy(self._watches)
end

---@return string[] lines The last `Consts.MONITOR_LOG_LINES` lines, oldest first
function MonitorTarget:get_log()
    return table.copy(self._log)
end

---@return integer The number of the newest line of the log, counting every line ever appended from 1
function MonitorTarget:get_log_end()
    return self._log_end
end

---@param text string Appended line by line
function MonitorTarget:append_log(text)
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        table.insert(self._log, line)
        self._log_end = self._log_end + 1
    end
    while #self._log > Consts.MONITOR_LOG_LINES do
        table.remove(self._log, 1)
    end
    self:_changed()
end

---@param dt number
function MonitorTarget:update(dt)
    local client = self._client
    if client then
        ---@type boolean, boolean
        local ok, open = pcall(client.poll, client, 0)
        if not ok or not open then
            self:_drop()
        end
        self:_complete_evaluations()
    elseif app:get_time() >= self._next_attempt then
        self:_connect()
    end
end

---@param chunk string Lua, run by the target's console
---@param on_reply MonitorReplyHandler Run with the reply, or with `false` and the reason when there is none
function MonitorTarget:evaluate(chunk, on_reply)
    assert_type(chunk, "string")
    assert_type(on_reply, "function")
    local request = self:_request(chunk)
    if not request then
        on_reply(false, string.format("%s is not connected", self._name))
        return
    end
    table.insert(self._evaluations, {
        request = request,
        on_reply = on_reply
    })
end

---@param expr string A Lua expression, also the watch's name
---@param on_reply MonitorReplyHandler|nil Run with the reply of the `watch` call
function MonitorTarget:add_watch(expr, on_reply)
    assert_type(expr, "string")
    self:evaluate(string.format("watch(%q, function() return %s end)", expr, expr), on_reply or function()
    end)
end

---@param name string
function MonitorTarget:remove_watch(name)
    assert_type(name, "string")
    if self._watches[name] then
        self._watches[name] = nil
        self:_changed()
    end
    self:_request(string.format("unwatch(%q)", name))
end

---@private
function MonitorTarget:_changed()
    self._revision = self._revision + 1
end

---@private
---@param state MonitorTargetState
function MonitorTarget:_set_state(state)
    if self._state ~= state then
        self._state = state
        self:_changed()
    end
end

---@private
function MonitorTarget:_connect()
    ---@type ConsoleClient|nil
    local client = nil
    pcall(function()
        client = ConsoleClient(self._port, self._host, self._tcp)
    end)
    if not client then
        self._next_attempt = app:get_time() + Consts.MONITOR_RECONNECT_SECONDS
        self:_set_state("connecting")
        return
    end
    client:set_frame_handler(function(kind, body)
        self:_on_frame(kind, body)
    end)
    self._client = client
    self._watches = {}
    self:_set_state("connected")
    self:_changed()
    app:log(string.format("monitor: %s connected to %s:%s", self._name, self._host, self._port))
    self:_request("log(true)")
end

---@private
function MonitorTarget:_drop()
    local client = assert(self._client)
    self._client = nil
    client:close()
    self._next_attempt = app:get_time() + Consts.MONITOR_RECONNECT_SECONDS
    self:_set_state("closed")
    app:log(string.format("monitor: %s closed", self._name))
end

---@private
---@param chunk string
---@return ConsoleRequest|nil request `nil` when not connected or the connection closed on sending
function MonitorTarget:_request(chunk)
    local client = self._client
    if not client then
        return nil
    end
    ---@type ConsoleRequest|nil
    local request = nil
    pcall(function()
        request = client:request_async(chunk)
    end)
    if not request then
        self:_drop()
        self:_complete_evaluations()
    end
    return request
end

---@private
function MonitorTarget:_complete_evaluations()
    while self._evaluations[1] and self._evaluations[1].request:is_done() do
        local evaluation = self._evaluations[1]
        table.remove(self._evaluations, 1)
        local request = evaluation.request
        ---@type boolean, any
        local replied, err = pcall(request.get_result, request)
        if replied then
            evaluation.on_reply(request:get_result())
        else
            evaluation.on_reply(false, tostring(err))
        end
    end
end

---@private
---@param kind string
---@param body string
function MonitorTarget:_on_frame(kind, body)
    if kind == "watch" then
        local name, frame, time, value = string.match(body, "^([^\t]*)\t(%d+)\t([^\t]*)\t(.*)$")
        if name and frame and time and value then
            self._watches[name] = {
                value = value,
                frame = assert(tonumber(frame)),
                time = tonumber(time) or 0
            }
            self:_changed()
        end
    elseif kind == "log" then
        self:append_log(body)
    end
end

return MonitorTarget

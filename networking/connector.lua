---@alias ConnectorMessage
---| {[1]: "a", [2]: love.Channel, [3]: love.Channel} # A peer connected: its in channel (what it sends) and its out channel (what to send it)
---| {[1]: "d", [2]: love.Channel} # A peer disconnected: its in channel
---@class Connector: Object
---@field private _address string
---@field private _port string
---@field private _channel love.Channel What the host thread reports
---@field private _stop_channel love.Channel A value on it asks the host thread to disconnect its peers and end
---@field private _retry_time number
---@field private _thread love.Thread|nil The host thread, from `start` on: one per side, started again once it ends, until `stop`
---@field private _connection_manager ConnectionManager
---@field private _last_start number|nil Time of the last host thread start
local Connector = class("Connector")

---@param address string
---@param port string
function Connector:init(address, port)
    self._address = address
    self._port = port
    self._channel = love.thread.newChannel()
    self._stop_channel = love.thread.newChannel()
    self._retry_time = 1
    self._thread = nil
    self._connection_manager = nil
end

---@param connection_manager ConnectionManager
function Connector:start(connection_manager)
    self._connection_manager = connection_manager
    if app.is_server then
        self._thread = love.thread.newThread("networking/detail/server-host.lua")
    else
        self._thread = love.thread.newThread("networking/detail/client-host.lua")
    end
    self:_try_restart_connection()

    app.update_event:register(self, self.on_update)
end

---@private
function Connector:_try_restart_connection()
    local thread = assert(self._thread)
    if thread:isRunning() then
        return
    end
    local now = love.timer.getTime()
    if self._last_start and now - self._last_start < self._retry_time then
        return
    end
    local err = thread:getError()
    if err then
        app:log("The host thread failed: " .. err)
    end
    self._last_start = now
    thread:start(app.logger:get_data(), self._channel, self._stop_channel, self._address, self._port)
end

---Ends the networking: the host thread disconnects its peers, which hear
---of it at once instead of timing out, and this blocks until it has, up
---to the disconnect timeout. A connector that was never started has
---nothing to end.
function Connector:stop()
    local thread = self._thread
    if not thread then
        return
    end
    app.update_event:unregister(self)
    if thread:isRunning() then
        self._stop_channel:push(true)
        thread:wait()
    end
end

---@private
function Connector:_handle_connections()
    while true do
        local msg = self._channel:pop() --[[@as ConnectorMessage|nil]]
        if not msg then
            break
        end
        local action, in_channel, out_channel = unpack(msg)
        if action == "a" then
            self._connection_manager:add_connection(in_channel, out_channel)
        elseif action == "d" then
            self._connection_manager:remove_by_in_channel(in_channel)
        end
    end
end

function Connector:on_update()
    self:_try_restart_connection()
    self:_handle_connections()
end

return Connector

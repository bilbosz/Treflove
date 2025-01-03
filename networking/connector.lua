local UpdateEventListener = require("events.update-event").Listener

---@class Connector: UpdateEventListener
---@field private _address string
---@field private _port string
---@field private _channel love.Channel
---@field private _retry_time number
---@field private _thread love.Thread
---@field private _connection_manager ConnectionManager
local Connector = class("Connector", UpdateEventListener)

---@param address string
---@param port string
function Connector:init(address, port)
    self._address = address
    self._port = port
    self._channel = love.thread.newChannel()
    self._retry_time = 1
    self._thread = nil
    self._connection_manager = nil
end

---@param connection_manager ConnectionManager
function Connector:start(connection_manager)
    self._connection_manager = connection_manager
    self:_try_restart_connection()

    app.update_event_manager:register_listener(self)
end

---@private
function Connector:_try_restart_connection()
    local now = love.timer.getTime()
    if not self._thread or not self._thread:isRunning() and (not self._last_start or now - self._last_start >= self._retry_time) then
        self._last_start = love.timer.getTime()
        if not self._thread then
            if app.is_server then
                self._thread = love.thread.newThread("networking/detail/connection-dispatcher.lua")
            else
                self._thread = love.thread.newThread("networking/detail/client-out.lua")
            end
        end
        if app.is_server then
            self._thread:start(app.logger:get_data(), self._channel, self._address, self._port)
        else
            self._thread:start(app.logger:get_data(), self._channel, self._address, self._port, self._thread)
        end
    end
end

---@private
function Connector:_handle_connections()
    while true do
        local msg = self._channel:pop()
        if not msg then
            break
        end
        local action, channel1, thread1, channel2, thread2 = unpack(msg)
        if action == "a" then
            self._connection_manager:add_connection(channel1, thread1, channel2, thread2)
        elseif action == "i" then
            self._connection_manager:remove_by_in_channel(channel1)
        elseif action == "o" then
            self._connection_manager:remove_by_out_channel(channel1)
        end
    end
end

function Connector:remove_thread()
    self._thread = nil
end

function Connector:on_update()
    self:_try_restart_connection()
    self:_handle_connections()
end

return Connector

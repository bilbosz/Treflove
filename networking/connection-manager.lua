local Connector = require("networking.connector")
local Connection = require("networking.connection")

---@alias ConnectionManagerOnConnect fun(connection:Connection)
---@alias ConnectionManagerOnDisconnect fun(connection:Connection)

---@class ConnectionManager
---@field private _connections table<Connection, boolean>
---@field private _by_in_channel table<love.Channel, Connection>
---@field private _by_out_channel table<love.Channel, Connection>
---@field private _on_connect ConnectionManagerOnConnect
---@field private _on_disconnect ConnectionManagerOnDisconnect
---@field private _connector Connector
local ConnectionManager = class("ConnectionManager")

---@param address string
---@param port string
function ConnectionManager:init(address, port)
    self._connections = {}
    self._by_in_channel = {}
    self._by_out_channel = {}
    self._on_connect = nil
    self._on_disconnect = nil
    self._connector = Connector(address, port)
end

---@param on_connect ConnectionManagerOnConnect
---@param on_disconnect ConnectionManagerOnDisconnect
function ConnectionManager:start(on_connect, on_disconnect)
    self._on_connect = on_connect
    self._on_disconnect = on_disconnect
    self._connector:start(self)
end

---@param in_channel love.Channel
---@param in_thread love.Thread
---@param out_channel love.Channel
---@param out_thread love.Thread
function ConnectionManager:add_connection(in_channel, in_thread, out_channel, out_thread)
    local connection = Connection(in_channel, in_thread, out_channel, out_thread)
    self._connections[connection] = true
    self._by_in_channel[in_channel] = connection
    self._by_out_channel[out_channel] = connection
    self._on_connect(connection)
end

---@param in_channel love.Channel
function ConnectionManager:remove_by_in_channel(in_channel)
    self:remove(self._by_in_channel[in_channel])
end

---@param out_channel love.Channel
function ConnectionManager:remove_by_out_channel(out_channel)
    self:remove(self._by_out_channel[out_channel])
end

---@param connection Connection
function ConnectionManager:remove(connection)
    self._connections[connection] = nil
    self._by_in_channel[connection:get_in_channel()] = nil
    self._by_out_channel[connection:get_out_channel()] = nil
    self._on_disconnect(connection)
    if app.is_client then
        self._connector:remove_thread()
    end
    connection:release()
end

---@return table<Connection, boolean>
function ConnectionManager:get_connections()
    return self._connections
end

return ConnectionManager

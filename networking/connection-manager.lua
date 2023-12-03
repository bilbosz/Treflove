local Connector = require("networking.connector")
local Connection = require("networking.connection")

---@class ConnectionManager
local ConnectionManager = class("ConnectionManager")

function ConnectionManager:init(address, port)
    self._connections = {}
    self._by_in_channel = {}
    self._by_out_channel = {}
    self._on_connect = nil
    self._connector = Connector(address, port)
end

function ConnectionManager:start(on_connect, on_disconnect)
    self._on_connect = on_connect
    self._on_disconnect = on_disconnect
    self._connector:start(self)
end

---@param in_channel LoveChannel
---@param in_thread LoveThread
---@param out_channel LoveChannel
---@param out_thread LoveThread
---@return void
function ConnectionManager:add_connection(in_channel, in_thread, out_channel, out_thread)
    local connection = Connection(in_channel, in_thread, out_channel, out_thread)
    self._connections[connection] = true
    self._by_in_channel[in_channel] = connection
    self._by_out_channel[out_channel] = connection
    self._on_connect(connection)
end

function ConnectionManager:remove_by_in_channel(in_channel)
    self:remove(self._by_in_channel[in_channel])
end

function ConnectionManager:remove_by_out_channel(out_channel)
    self:remove(self._by_out_channel[out_channel])
end

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

function ConnectionManager:get_connections()
    return self._connections
end

return ConnectionManager

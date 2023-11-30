local Connector = require("networking.connector")
local Connection = require("networking.connection")

---@class ConnectionManager
local ConnectionManager = class("ConnectionManager")

function ConnectionManager:init(address, port)
    self.connections = {}
    self.byInChannel = {}
    self.byOutChannel = {}
    self.onConnect = nil
    self.connector = Connector(address, port)
end

function ConnectionManager:start(onConnect, onDisconnect)
    self.onConnect = onConnect
    self.onDisconnect = onDisconnect
    self.connector:start(self)
end

function ConnectionManager:add_connection(inChannel, inThread, outChannel, outThread)
    local connection = Connection(inChannel, inThread, outChannel, outThread)
    self.connections[connection] = true
    self.byInChannel[inChannel] = connection
    self.byOutChannel[outChannel] = connection
    self.onConnect(connection)
end

function ConnectionManager:remove_by_in_channel(inChannel)
    self:remove(self.byInChannel[inChannel])
end

function ConnectionManager:remove_by_out_channel(outChannel)
    self:remove(self.byOutChannel[outChannel])
end

function ConnectionManager:remove(connection)
    self.connections[connection] = nil
    self.byInChannel[connection:get_in_channel()] = nil
    self.byOutChannel[connection:get_out_channel()] = nil
    self.onDisconnect(connection)
    if app.is_client then
        self.connector:remove_thread()
    end
    connection:release()
end

function ConnectionManager:get_connections()
    return self.connections
end

return ConnectionManager

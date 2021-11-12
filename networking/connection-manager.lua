ConnectionManager = {}

function ConnectionManager:Init(address, port)
    self.connections = {}
    self.byInChannel = {}
    self.byOutChannel = {}
    self.onConnect = nil
    self.connector = Connector(address, port)
end

function ConnectionManager:Start(onConnect, onDisconnect)
    self.onConnect = onConnect
    self.onDisconnect = onDisconnect
    self.connector:Start(self)
end

function ConnectionManager:AddConnection(inChannel, inThread, outChannel, outThread)
    local connection = Connection(inChannel, inThread, outChannel, outThread)
    self.connections[connection] = true
    self.byInChannel[inChannel] = connection
    self.byOutChannel[outChannel] = connection
    self.onConnect(connection)
end

function ConnectionManager:RemoveByInChannel(inChannel)
    self:Remove(self.byInChannel[inChannel])
end

function ConnectionManager:RemoveByOutChannel(outChannel)
    self:Remove(self.byOutChannel[outChannel])
end

function ConnectionManager:Remove(connection)
    self.connections[connection] = nil
    self.byInChannel[connection:GetInChannel()] = nil
    self.byOutChannel[connection:GetOutChannel()] = nil
    self.onDisconnect(connection)
    if app.isClient then
        self.connector:RemoveThread()
    end
    connection:Release()
end

function ConnectionManager:GetConnections()
    return self.connections
end

MakeClassOf(ConnectionManager)

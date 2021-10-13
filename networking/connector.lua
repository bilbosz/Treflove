Connector = {}

function Connector:Init(address, port)
    UpdateObserver.Init(self)
    self.address = address
    self.port = port
    self.channel = love.thread.newChannel()
    if app.isServer then
        self.thread = love.thread.newThread("networking/impl/connection-dispatcher.lua")
    else
        self.thread = love.thread.newThread("networking/impl/client-out.lua")
    end
    self.newConnectionHandler = nil
end

function Connector:Start(newConnectionHandler)
    self.newConnectionHandler = newConnectionHandler
    self.thread:start(self.channel, self.address, self.port)
end

function Connector:Update()
    local channels = self.channel:pop()
    while channels do
        self.newConnectionHandler(Connection(channels[1], channels[2]))
        channels = self.channel:pop()
    end
end

Loader:LoadClass("events/update-observer.lua")
MakeClassOf(Connector, UpdateObserver)

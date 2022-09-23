Connector = {}

function Connector:Init(address, port)
    self.address = address
    self.port = port
    self.channel = love.thread.newChannel()
    self.retryTime = 1
    self.thread = nil
    self.connectionManager = nil
end

function Connector:Start(connectionManager)
    self.connectionManager = connectionManager
    self:TryRestartConnection()

    app.updateEventManager:RegisterListener(self)
end

function Connector:TryRestartConnection()
    local now = love.timer.getTime()
    if not self.thread or not self.thread:isRunning() and (not self.lastStart or now - self.lastStart >= self.retryTime) then
        self.lastStart = love.timer.getTime()
        if not self.thread then
            if app.isServer then
                self.thread = love.thread.newThread("networking/impl/connection-dispatcher.lua")
            else
                self.thread = love.thread.newThread("networking/impl/client-out.lua")
            end
        end
        if app.isServer then
            self.thread:start(app.logger:GetData(), self.channel, self.address, self.port)
        else
            self.thread:start(app.logger:GetData(), self.channel, self.address, self.port, self.thread)
        end
    end
end

function Connector:HandleConnections()
    while true do
        local msg = self.channel:pop()
        if not msg then
            break
        end
        local action, channel1, thread1, channel2, thread2 = unpack(msg)
        if action == "a" then
            self.connectionManager:AddConnection(channel1, thread1, channel2, thread2)
        elseif action == "i" then
            self.connectionManager:RemoveByInChannel(channel1)
        elseif action == "o" then
            self.connectionManager:RemoveByOutChannel(channel1)
        end
    end
end

function Connector:RemoveThread()
    self.thread = nil
end

function Connector:OnUpdate()
    self:TryRestartConnection()
    self:HandleConnections()
end

MakeClassOf(Connector, UpdateEventListener)

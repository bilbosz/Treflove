Client = {}

function Client:Init(params)
    App.Init(self, params)
    self.channel = love.thread.newChannel()
    self.connection = love.thread.newThread("app/client/client-connection.lua")
end

function Client:Load()
    self.connection:start(self.channel, params)
end

function Client:Draw()
    if self.screen then
        self.screen:Draw()
    end
end

function Client:Update(dt)
    local message = self.channel:pop()
    while message do
        self.data = table.fromstring(message)
        self.screen = Game(app.data.game)
        message = self.channel:pop()
    end
    if self.screen then
        self.screen:Update(dt)
    end
end

function Client:KeyPressed(key)
    if self.screen then
        self.screen:KeyPressed(key)
    end
end

function Client:WheelMoved(x, y)
    if self.screen then
        self.screen:WheelMoved(x, y)
    end
end

function Client:MousePressed(x, y, button)
    if self.screen then
        self.screen:MousePressed(x, y, button)
    end
end

function Client:MouseReleased(x, y, button)
    if self.screen then
        self.screen:MouseReleased(x, y, button)
    end
end

function Client:MouseMoved(x, y)
    if self.screen then
        self.screen:MouseMoved(x, y)
    end
end

Loader:LoadClass("app/app.lua")
MakeClassOf(Client, App)
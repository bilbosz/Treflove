Client = {}

function Client:Init(params)
    App.Init(self, params)
    self.isClient = true
    self.channel = love.thread.newChannel()
    self.connector = Connector(params.address, params.port)
    self.connection = nil
end

function Client:Load()
    self.connector:Start(function(connection)
        self.connection = connection
        connection:Start(function(msg)
            self.data = table.fromstring(msg)
            self.screen = Game(app.data.game)
        end)
    end)
end

function Client:Draw()
    if self.screen then
        self.screen:Draw()
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

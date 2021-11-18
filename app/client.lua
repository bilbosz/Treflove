Client = {}

function Client:Init(params)
    App.Init(self, params)
    self.isClient = true
    self.connectionManager = ConnectionManager(params.address, params.port)
    self.screenManager = ScreenManager()
    self.pointerEventManager = PointerEventManager()
    self.wheelEventManager = WheelEventManager()
end

function Client:Load()
    self.screenManager:Push(ConnectionScreen())
    self.connectionManager:Start(function(connection)
        self.connection = connection
        connection:Start(function(msg)
            self.data = msg
            self.screenManager:Push(Game(app.data.game))
            return {}
        end)
    end, function()
        self.screenManager:Pop()
        self.connection = nil
        self.data = nil
    end)
end

MakeClassOf(Client, App)

Client = {}

function Client:Init(params)
    App.Init(self, params)
    self.isClient = true
    self.connectionManager = ConnectionManager(params.address, params.port)
    self.screenManager = ScreenManager()
    self.pointerEventManager = PointerEventManager()
    self.wheelEventManager = WheelEventManager()
    self.buttonEventManager = ButtonEventManager()
end

function Client:Load()
    self.screenManager:Push(ConnectionScreen())
    self.connectionManager:Start(function(connection)
        self.connection = connection
        self.screenManager:Push(LoginScreen())
        connection:Start(function()
            return {}
        end)
    end, function()
        self.screenManager:Pop()
        self.connection = nil
        self.data = nil
    end)
end

MakeClassOf(Client, App)

Client = {}

function Client:Init(params)
    App.Init(self, params)
    self.isClient = true
    self.connectionManager = ConnectionManager(params.address, params.port)
    self.screenManager = ScreenManager()
    self.pointerEventManager = PointerEventManager()
    self.wheelEventManager = WheelEventManager()
    self.buttonEventManager = ButtonEventManager()
    self.textEventManager = TextEventManager()
    self.focusEventManager = FocusEventManager()
    self.login = Login()
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
        while self.screenManager:ScreenCount() > 1 do
            self.screenManager:Pop()
        end
        self.connection = nil
        self.data = nil
    end)
end

function Client:RegisterLoveCallbacks()
    App.RegisterLoveCallbacks(self)
    local appKeyPressed = love.keypressed
    function love.keypressed(key)
        appKeyPressed(key)
        self.textEventManager:KeyPressed(key)
        self.focusEventManager:KeyPressed(key)
    end
    function love.wheelmoved(x, y)
        self.wheelEventManager:InvokeEvent(WheelEventListener.OnWheelMoved, x, y)
    end
    function love.mousepressed(x, y, button)
        self.pointerEventManager:PointerDown(x, y, button)
        self.buttonEventManager:PointerDown(x, y, button)
    end
    function love.mousereleased(x, y, button)
        self.pointerEventManager:PointerUp(x, y, button)
        self.buttonEventManager:PointerUp(x, y, button)
    end
    function love.mousemoved(x, y)
        self.pointerEventManager:PointerMove(x, y, nil)
        self.buttonEventManager:PointerMove(x, y, nil)
    end
    function love.touchpressed(id, x, y)
        self.pointerEventManager:PointerDown(x, y, id)
        self.buttonEventManager:PointerDown(x, y, id)
    end
    function love.touchreleased(id, x, y)
        self.pointerEventManager:PointerUp(x, y, id)
        self.buttonEventManager:PointerUp(x, y, id)
    end
    function love.touchmoved(id, x, y)
        self.pointerEventManager:PointerMove(x, y, id)
        self.buttonEventManager:PointerMove(x, y, id)
    end
    function love.textinput(text)
        self.textEventManager:TextInput(text)
    end
end

MakeClassOf(Client, App)

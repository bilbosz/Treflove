Client = {}

function Client:Init(params)
    App.Init(self, params)
    self.logger:SetName("client-main")
    self.isClient = true
    self.connectionManager = ConnectionManager(params.address, params.port)
    self.resizeManager = ResizeManager()
    self.screenManager = ScreenManager()
    self.pointerEventManager = PointerEventManager()
    self.wheelEventManager = WheelEventManager()
    self.buttonEventManager = ButtonEventManager()
    self.keyboardManager = KeyboardManager()
    self.textEventManager = TextEventManager()
    self.notificationManager = NotificationManager()
    self.optionsManager = OptionsManager()
    self.assetManager = AssetManager()
    self.backstackManager = BackstackManager()
    self.fileDragManager = FileDropEventManager()
    self.session = nil
end

function Client:Load()
    self.backstackManager:Push(function()
        app:Quit()
    end)
    local connectionScreen = ConnectionScreen()
    self.screenManager:Show(connectionScreen)
    self.connectionManager:Start(function(connection)
        self.session = Session(connection)
    end, function()
        self.screenManager:Show(connectionScreen)
        self.session:Release()
        self.session = nil
        self.data = nil
    end)
end

function Client:RegisterLoveCallbacks()
    App.RegisterLoveCallbacks(self)
    local appKeyPressed = love.keypressed
    function love.keypressed(key)
        appKeyPressed(key)
        if key == Consts.TOGGLE_FULLSCREEN_KEY then
            self.resizeManager:ToggleFullscreen()
            return
        end
        self.keyboardManager:KeyPressed(key)
        self.textEventManager:KeyPressed(key)
    end
    function love.keyreleased(key)
        self.keyboardManager:KeyReleased(key)
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
    function love.filedropped(file)
        local x, y = self.pointerEventManager:GetPosition()
        self.fileDragManager:FileDrop(x, y, file)
    end
    function love.directorydropped(path)
        local x, y = self.pointerEventManager:GetPosition()
        self.fileDragManager:DirectoryDrop(x, y, path)
    end
    function love.textinput(text)
        self.textEventManager:TextInput(text)
    end
    function love.resize()
        self.resizeManager:Resize()
    end
end

MakeClassOf(Client, App)

App = {}

local function CreateRoot(self)
    local realW, realH = love.graphics.getDimensions()
    assert(realW >= realH)
    local scale = realW / Consts.MODEL_WIDTH
    self.width, self.height = Consts.MODEL_WIDTH, realH / scale
    self.root = Control()
    self.root:SetScale(scale)
end

local function RegistryLoveCallbacks(self)
    if self.Load then
        function love.load()
            self:Load()
        end
    end
    if config.window then
        CreateRoot(self)
        if debug then
            function love.draw()
                if self.root:IsEnabled() then
                    self.root:Draw()
                    love.graphics.reset()
                    if self.drawAabs then
                        DrawAabbs(self.root)
                        love.graphics.reset()
                    end
                end
            end
        else
            function love.draw()
                if self.root:IsEnabled() then
                    self.root:Draw()
                    love.graphics.reset()
                end
            end
        end
        function love.keypressed(key)
            if key == "escape" then
                self.markForQuit = true
                return
            elseif key == "f2" then
                self.drawAabs = not self.drawAabs
            end
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
    end
    function love.update(dt)
        if self.markForQuit then
            love.event.quit(0)
        end
        self.updateEventManager:InvokeEvent(UpdateEventListener.OnUpdate, dt)
        collectgarbage("step")
    end
end

function App:Quit()
    self.markForQuit = true
end

function App:Init(params)
    app = self
    self.logger = Logger({}, "main")
    self.params = params
    self.isServer = false
    self.isClient = false
    self.data = nil
    self.width = nil
    self.height = nil
    self.root = nil
    self.updateEventManager = UpdateEventManager()

    RegistryLoveCallbacks(self)
end

MakeClassOf(App)

App = {}

local socket = require("socket")

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
        function love.draw()
            self.root:Draw()
            love.graphics.reset()
        end
        function love.keypressed(key)
            if key == "escape" then
                love.event.quit(0)
                return
            end
        end
        function love.wheelmoved(x, y)
            self.root:WheelMoved(x, y)
        end
        function love.mousepressed(x, y, button)
            self.root:MousePressed(x, y, button)
        end
        function love.mousereleased(x, y, button)
            self.root:MouseReleased(x, y, button)
        end
        function love.mousemoved(x, y)
            self.root:MouseMoved(x, y)
        end
    end
    function love.update(dt)
        self.updateEventManager:InvokeEvent(UpdateEventListener.OnUpdate, dt)
        collectgarbage("step")
    end
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

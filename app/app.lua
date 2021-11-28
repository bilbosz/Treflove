App = {}

local function CreateRoot(self)
    local realW, realH = love.graphics.getDimensions()
    assert(realW >= realH)
    local scale = realW / Consts.MODEL_WIDTH
    self.width, self.height = Consts.MODEL_WIDTH, realH / scale
    self.root = Control()
    self.root:SetScale(scale)
end

function App:RegisterLoveCallbacks()
    if self.Load then
        function love.load()
            self:Load()
        end
    end

    if config.window then
        CreateRoot(self)
        if debug then
            function love.draw()
                local root = self.root
                if root:IsVisible() then
                    self.root:Draw()
                    love.graphics.reset()
                    if self.drawAabs then
                        DrawAabbs(self.root)
                    end
                end
                love.graphics.reset()
            end
        else
            function love.draw()
                local root = self.root
                if root:IsVisible() then
                    self.root:Draw()
                end
                love.graphics.reset()
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

    self:RegisterLoveCallbacks()
end

MakeClassOf(App)

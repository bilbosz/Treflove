App = {}

function App:RegisterLoveCallbacks()
    if self.Load then
        function love.load()
            self:Load()
        end
    end

    if config.window then
        self.root = Control()
        self:RescaleRoot()
        if debug then
            function love.draw()
                if self.root:IsVisible() then
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
                if self.root:IsVisible() then
                    self.root:Draw()
                end
                love.graphics.reset()
            end
        end
        function love.keypressed(key)
            if key == Consts.DRAW_AABBS_KEY then
                self.drawAabs = not self.drawAabs
            elseif key == Consts.QUIT_KEY then
                self:Quit()
            end
        end
    end

    if debug then
        function love.errorhandler(msg)
            print(string.format("%s error: \"%s\"", app.isClient and "Client" or "Server", msg))
            print(GetStacktrace(2))
        end
    else
        function love.errorhandler()

        end
    end

    function love.update(dt)
        self.deferManager:Update()
        if self.markForQuit then
            love.event.quit(0)
        end
        self.time = GetTime() - self.startTime
        self.updateEventManager:InvokeEvent(UpdateEventListener.OnUpdate, dt)
        collectgarbage("step")
    end
end

function App:GetTime()
    return self.time
end

function App:Quit()
    self.markForQuit = true
end

function App:Log(...)
    local format = string.rep("%s", select("#", ...), " ")
    self.logger:LogUp(format, 1, ...)
end

function App:LogFun(...)
    local format = ""
    if debug then
        local info = debug.getinfo(2, "n")
        format = string.format("%s ", info.name)
    end
    format = format .. string.rep("%s ", select("#", ...), " ")
    self.logger:LogUp(format, 1, ...)
end

function App:RescaleRoot()
    local realW, realH = love.graphics.getDimensions()
    local scale = realW / Consts.MODEL_WIDTH
    self.width, self.height = Consts.MODEL_WIDTH, realH / scale
    self.root:SetScale(scale)
end

function App:Init(params)
    app = self
    self.startTime = GetTime()
    self.logger = Logger({
        startTime = self.startTime
    }, "main")
    self.params = params
    self.isServer = false
    self.isClient = false
    self.data = nil
    self.width = nil
    self.height = nil
    self.root = nil
    self.time = 0
    self.updateEventManager = UpdateEventManager()
    self.deferManager = DeferManager()

    self:RegisterLoveCallbacks()
end

MakeClassOf(App)

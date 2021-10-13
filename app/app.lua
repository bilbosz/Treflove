App = {}

function App:RegistryLoveCallbacks()
    if self.Load then
        function love.load()
            self:Load()
        end
    end
    if self.Draw then
        function love.draw()
            self:Draw()
        end
    end
    if self.KeyPressed then
        function love.keypressed(key)
            if key == "escape" then
                love.event.quit(0)
                return
            elseif debug and key == "f11" then
                Loader:ReloadClasses()
                ReloadObjects()
                return
            end
            self:KeyPressed(key)
        end
    end
    if self.WheelMoved then
        function love.wheelmoved(x, y)
            self:WheelMoved(x, y)
        end
    end
    if self.MousePressed then
        function love.mousepressed(x, y, button)
            self:MousePressed(x, y, button)
        end
    end
    if self.MouseReleased then
        function love.mousereleased(x, y, button)
            self:MouseReleased(x, y, button)
        end
    end
    if self.MouseMoved then
        function love.mousemoved(x, y)
            self:MouseMoved(x, y)
        end
    end
    function love.update(dt)
        UpdateObserver.Notify(dt)
        collectgarbage("step")
    end
end

function App:Init(params)
    app = self
    self.params = params
    self.isServer = false
    self.isClient = false
    self.data = nil

    self:RegistryLoveCallbacks()
end

MakeClassOf(App)

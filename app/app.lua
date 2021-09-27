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
    if self.Update then
        function love.update(dt)
            self:Update(dt)
            collectgarbage("step")
        end
    end
    if self.KeyPressed then
        function love.keypressed(key)
            if key == "escape" then
                love.event.quit(0)
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
end

function App:Init(params)
    self.params = params
    self.isServer = false
    self.isClient = false
    self.data = nil

    self:RegistryLoveCallbacks()
end

function App:PostInit()
end

MakeClass(App)
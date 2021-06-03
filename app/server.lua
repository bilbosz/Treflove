Server = class("Server", App)

Loader:Load("game/game.lua")

function Server:Init(params)
    self.App.Init(self, params)
    self.game = Game()
end

function Server:Draw()
    self.game:Draw()
end

function Server:Update(dt)
    self.game:Update(dt)
end

function Server:KeyPressed(key)
    if key == "f9" then
        Loader:Load("game/game.lua")
        self.game = Game()
    end
    self.game:KeyPressed(key)
end

function Server:WheelMoved(x, y)
    self.game:WheelMoved(x, y)
end

function Server:MousePressed(x, y, button)
    self.game:MousePressed(x, y, button)
end

function Server:MouseReleased(x, y, button)
    self.game:MouseReleased(x, y, button)
end

function Server:MouseMoved(x, y)
    self.game:MouseMoved(x, y)
end

return Server

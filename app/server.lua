Server = class("Server", App)

Loader:Load("game/game.lua")

function Server:Init(params)
    App.Init(self, params)
    self:LoadData("save/game-01.lua")
    self.screen = _G[self.data.screen.group](self.data)
end

function Server:Draw()
    self.screen:Draw()
end

function Server:Update(dt)
    self.screen:Update(dt)
end

function Server:KeyPressed(key)
    if key == "f9" then
        self:LoadData("save/game-01.lua")
        self.screen = _G[self.data.screen.group](self.data)
    elseif key == "f5" then
        self:SaveData("save/game-02")
    end
    self.screen:KeyPressed(key)
end

function Server:WheelMoved(x, y)
    self.screen:WheelMoved(x, y)
end

function Server:MousePressed(x, y, button)
    self.screen:MousePressed(x, y, button)
end

function Server:MouseReleased(x, y, button)
    self.screen:MouseReleased(x, y, button)
end

function Server:MouseMoved(x, y)
    self.screen:MouseMoved(x, y)
end

function Server:LoadData(file)
    local data = Loader:Load(file)
    -- TODO Verify data before use
    self.data = data
end

function Server:SaveData(file)
    local packedData = love.data.pack(self.data)
    local success, message = love.filesystem.write(file, packedData)
    assert(success, message)
end

return Server

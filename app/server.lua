Server = class("Server", App)

Loader:Load("game/game.lua")

local function TryCreateDataDirectory(self)
    local info = love.filesystem.getInfo(love.filesystem.getSaveDirectory() .. "/" .. self.DATA_DIR)
    assert(not info or info.type == "directory")
    if not info then
        return love.filesystem.createDirectory(self.DATA_DIR)
    end
    return true
end

function Server:Init(params)
    App.Init(self, params)
    self.DATA_DIR = "save"
    assert(TryCreateDataDirectory(self))
end

function Server:PostInit()
    self:LoadData("game-01.lua")
end

function Server:Draw()
    self.screen:Draw()
end

function Server:Update(dt)
    self.screen:Update(dt)
end

function Server:KeyPressed(key)
    if key == "f9" then
        self:LoadData("game-01.lua")
    elseif key == "f5" then
        self:SaveData("game-02.lua")
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
    local content = love.filesystem.read(self.DATA_DIR .. "/" .. file)
    self.data = table.fromstring(content)
    self.screen = Game(app.data.game)
end

function Server:SaveData(file)
    local content = table.tostring(self.data)
    local success, message = love.filesystem.write(self.DATA_DIR .. "/" .. file, content)
    assert(success, message)
end

return Server

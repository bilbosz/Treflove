Client = {}

local function TryCreateDataDirectory(self)
    local info = love.filesystem.getInfo(love.filesystem.getSaveDirectory() .. "/" .. self.DATA_DIR)
    assert(not info or info.type == "directory")
    if not info then
        return love.filesystem.createDirectory(self.DATA_DIR)
    end
    return true
end

function Client:Init(params)
    App.Init(self, params)
    self.DATA_DIR = "save"
    self.DATA_FILE = "game-01.lua"
    assert(TryCreateDataDirectory(self))
end

function Client:Load()
    self:LoadData(self.DATA_FILE)
end

function Client:Draw()
    self.screen:Draw()
end

function Client:Update(dt)
    self.screen:Update(dt)
end

function Client:KeyPressed(key)
    if key == "f9" then
        self:LoadData(self.DATA_FILE)
    elseif key == "f5" then
        self:SaveData(self.DATA_FILE)
    end
    self.screen:KeyPressed(key)
end

function Client:WheelMoved(x, y)
    self.screen:WheelMoved(x, y)
end

function Client:MousePressed(x, y, button)
    self.screen:MousePressed(x, y, button)
end

function Client:MouseReleased(x, y, button)
    self.screen:MouseReleased(x, y, button)
end

function Client:MouseMoved(x, y)
    self.screen:MouseMoved(x, y)
end

function Client:LoadData(file)
    local content = love.filesystem.read(self.DATA_DIR .. "/" .. file)
    self.data = table.fromstring(content)
    self.screen = Game(app.data.game)
end

function Client:SaveData(file)
    local content = table.tostring(self.data)
    local success, message = love.filesystem.write(self.DATA_DIR .. "/" .. file, content)
    assert(success, message)
end

Loader:LoadClass("app/app.lua")
MakeClassOf(Client, App)

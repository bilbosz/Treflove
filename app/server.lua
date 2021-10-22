Server = {}

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
    self.isServer = true
    self.DATA_DIR = "save"
    self.DATA_FILE = "game-01.lua"
    assert(TryCreateDataDirectory(self))

    if config.window then
        self.screenSaver = ScreenSaver()
    end
    self.connectionManager = ConnectionManager(params.address, params.port)
end

function Server:Load()
    self:LoadData(self.DATA_FILE)
    self.connectionManager:Start(function(connection)
        connection:Start(function(msg)
            self.data = msg
            self:SaveData(self.DATA_FILE)
            for c in pairs(self.connectionManager:GetConnections()) do
                if c ~= connection then
                    c:SendRequest(self.data, function()
                        app.logger:Log("Received game data")
                    end)
                end
            end
        end)
        connection:SendRequest(self.data, function()
            app.logger:Log("Received game data")
        end)
    end, function(connection)
    end)
end

function Server:LoadData(file)
    local content = love.filesystem.read(self.DATA_DIR .. "/" .. file)
    self.data = table.fromstring(content)
end

function Server:SaveData(file)
    local content = table.tostring(self.data)
    local success, message = love.filesystem.write(self.DATA_DIR .. "/" .. file, content)
    assert(success, message)
end

if config.window then
    function Server:Draw()
        self.screenSaver:Draw()
    end
end

Loader.LoadFile("app/app.lua")
MakeClassOf(Server, App)

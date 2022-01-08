Server = {}

local function TryCreateDataDirectory(self)
    local info = love.filesystem.getInfo(love.filesystem.getSaveDirectory() .. "/" .. self.SAVE_DIR)
    assert(not info or info.type == "directory")
    if not info then
        return love.filesystem.createDirectory(self.SAVE_DIR)
    end
    return true
end

function Server:Init(params)
    App.Init(self, params)
    self.logger:SetName("server-main")
    self.isServer = true
    self.SAVE_DIR = "save"
    self.GAME_FILE = "game-01.lua"
    assert(TryCreateDataDirectory(self))

    if self.root then
        self.screenManager = ScreenManager()
        self.screenManager:Push(ScreenSaver())
    end
    self.sessions = {}
    self.connectionManager = ConnectionManager(params.address, params.port)
end

function Server:Load()
    self:LoadData(self.GAME_FILE)
    self.connectionManager:Start(function(connection)
        self.sessions[connection] = Session(connection)
    end, function(connection)
        local session = self.sessions[connection]
        session:Release()
        self.sessions[connection] = nil
    end)
end

function Server:LoadData(file)
    local content = love.filesystem.read(self.SAVE_DIR .. "/" .. file)
    self.data = table.fromstring(content)
end

function Server:SaveData(file)
    local content = table.tostring(self.data)
    local success, message = love.filesystem.write(self.SAVE_DIR .. "/" .. file, content)
    assert(success, message)
end

function Server:RegisterLoveCallbacks()
    App.RegisterLoveCallbacks(self)
end

MakeClassOf(Server, App)

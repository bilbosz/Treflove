Server = {}

function Server:Init(params)
    App.Init(self, params)
    self.logger:SetName("server-main")
    self.isServer = true
    self.saveFile = Asset("save.lua", true)

    if self.root then
        self.screenManager = ScreenManager()
        self.screenManager:Show(ScreenSaver())
    end
    self.sessions = {}
    self.connectionManager = ConnectionManager(params.address, params.port)
    self.assetManager = AssetManager()
end

function Server:Load()
    self:LoadData()
    self.connectionManager:Start(function(connection)
        self.sessions[connection] = Session(connection)
    end, function(connection)
        self.sessions[connection]:Release()
        self.sessions[connection] = nil
    end)
end

function Server:LoadData()
    local content = self.saveFile:Read()
    self.data = table.fromstring(content)
end

function Server:SaveData()
    local content = table.tostring(self.data)
    self.saveFile:Write(content)
end

function Server:RegisterLoveCallbacks()
    App.RegisterLoveCallbacks(self)
end

MakeClassOf(Server, App)

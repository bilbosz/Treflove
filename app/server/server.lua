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
    self.DATA_DIR = "save"
    self.DATA_FILE = "game-01.lua"
    assert(TryCreateDataDirectory(self))

    self.channel = love.thread.newChannel()
    self.dispatcher = love.thread.newThread("app/server/dispatcher.lua")
end

function Server:Load()
    self:LoadData(self.DATA_FILE)
    self.dispatcher:start(self.channel, params)
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

function Server:Update(dt)
    local channel = self.channel:pop()
    while channel do
        if channel then
            channel:push(table.tostring(self.data))
        end
        channel = self.channel:pop()
    end
end

Loader:LoadClass("app/app.lua")
MakeClassOf(Server, App)
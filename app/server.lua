local App = require("app.app")
local Asset = require("data.asset")
local AssetManager = require("data.asset-manager")
local Session = require("game.session")
local ConnectionManager = require("networking.connection-manager")
local ScreenManager = require("screens.screen-manager")
local ScreenSaver = require("screens.screen-saver")

---@class Server: App
---@field private _save_file Asset
---@field private _sessions table<Connection, Session>
local Server = class("Server", App)

---@param params ArgParserResult
function Server:init(params)
    App.init(self, params)
    self.logger:set_name("server-main")
    self.is_server = true
    self._save_file = Asset("save.lua", true)

    if self.root then
        self.screen_manager = ScreenManager()
        self.screen_manager:show(ScreenSaver())
    end
    self._sessions = {}
    self.connection_manager = ConnectionManager(params.address, params.port)
    self.asset_manager = AssetManager()
end

---@private
function Server:load()
    self:_load_data()
    self.connection_manager:start(function(connection)
        self._sessions[connection] = Session(connection)
    end, function(connection)
        self._sessions[connection]:release()
        self._sessions[connection] = nil
    end)
end

---@private
function Server:_load_data()
    local content = self._save_file:read()
    self.data = table.from_string(content)
end

---@private
function Server:save_data()
    local content = table.to_string(self.data)
    self._save_file:write(content)
end

---@private
function Server:register_love_callbacks()
    App.register_love_callbacks(self)
end

return Server

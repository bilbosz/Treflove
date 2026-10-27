local App = require("app.app")
local Console = require("app.console")
local Consts = require("app.consts")
local Accounts = require("data.accounts")
local Asset = require("data.asset")
local AssetManager = require("data.asset-manager")
local Games = require("data.games")
local fixture = require("data.fixture")
local Session = require("game.session")
local ConnectionManager = require("networking.connection-manager")
local ScreenManager = require("screens.screen-manager")
local ScreenSaver = require("screens.screen-saver")

---@class Server: App
---@field private _sessions table<Connection, Session>
local Server = class("Server", App)

---@param params ArgParserResult
function Server:init(params)
    App.init(self, params)
    self.logger:set_name("server-main")
    self.is_server = true

    if self.root then
        self.screen_manager = ScreenManager()
        self.screen_manager:show(ScreenSaver())
    end
    self._sessions = {}
    self.connection_manager = ConnectionManager(params.address, params.port)
    self.asset_manager = AssetManager()
    if params.console then
        self.console = Console(params.console)
    end
end

---@protected
function Server:load()
    if self.params.fixture then
        fixture.seed(self.params.fixture, Consts.SERVER_ROOT)
    end
    self.accounts = Accounts(Asset(Consts.SERVER_ROOT .. "/accounts.lua"))
    self.games = Games(Consts.SERVER_ROOT .. "/games")
    self.connection_manager:start(function(connection)
        self._sessions[connection] = Session(connection):attach_lifetime(connection)
    end, function(connection)
        self._sessions[connection] = nil
    end)
end

---@protected
function Server:register_love_callbacks()
    App.register_love_callbacks(self)
end

return Server

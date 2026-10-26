local Console = require("app.console")
local UiApp = require("app.ui-app")
local AssetManager = require("data.asset-manager")
local OptionsManager = require("game.options-manager")
local Session = require("game.session")
local ConnectionManager = require("networking.connection-manager")
local ConnectingScreen = require("screens.connecting-screen")
local ScenarioRunner = require("app.scenario-runner")

---@class Client: UiApp
---@field public data GameData|nil Cleared on a disconnect
local Client = class("Client", UiApp)

---@param params ArgParserResult
function Client:init(params)
    UiApp.init(self, params)
    self.logger:set_name("client-main")
    self.is_client = true
    self.connection_manager = ConnectionManager(params.address, params.port)
    self.options_manager = OptionsManager()
    self.asset_manager = AssetManager()
    self.session = nil
    if params.console then
        self.console = Console(params.console)
    end
end

---@protected
function Client:load()
    self.backstack_manager:push(function()
        app:quit()
    end)
    local connecting_screen = ConnectingScreen()
    self.screen_manager:show(connecting_screen)
    self.connection_manager:start(function(connection)
        local session = Session(connection):attach_lifetime(connection)
        self.session = session
        session:show_login()
    end, function()
        self.screen_manager:show(connecting_screen)
        self.session = nil
        self.data = nil
    end)
    if self.params.scenario or self.params.console then
        local runner = ScenarioRunner()
        self.scenario_runner = runner
        if self.params.scenario then
            runner:start(self.params.scenario, true)
        end
        if self.console then
            ---@param name string
            self.console:add_function("scenario", function(name)
                runner:start(name)
            end)
        end
    end
end

return Client

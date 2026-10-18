local RemoteProcedure = require("networking.remote-procedure")
local WaitingScreen = require("screens.waiting-screen")
local GameScreen = require("game.game-screen")
local lifetime = require("lifetime")

---@class GameDataResponse
---@field public data table Full game state served by the server

---@class GameDataRp: RemoteProcedure
local GameDataRp = class("GameDataRp", RemoteProcedure)

---@return string[] Asset paths required by the current page
local function _list_required_assets()
    local list = {}
    local data = app.data
    local page = data.pages[data.game.page]
    table.insert(list, page.image)
    for _, v in ipairs(page.tokens) do
        table.insert(list, data.tokens[v].avatar)
    end
    return list
end

---@param connection Connection
function GameDataRp:init(connection)
    RemoteProcedure.init(self, connection)
end

---@return GameDataResponse
function GameDataRp:send_response()
    return {
        data = app.data
    }
end

---@param response GameDataResponse
function GameDataRp:receive_response(response)
    app.data = response.data
    app.screen_manager:show(WaitingScreen("Synchronizing Assets..."))
    local list = _list_required_assets()
    app.asset_manager:download_missing_assets(list, function()
        -- lua-lifetime: the game screen belongs to the logged-in period:
        -- logging out or disconnecting destroys it, with its panels.
        app.screen_manager:show(lifetime.attach(GameScreen(app.data.game), app.session:get_period()))
    end)
end

return GameDataRp

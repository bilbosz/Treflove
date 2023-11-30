local RemoteProcedure = require("networking.remote-procedure")
local WaitingScreen = require("screens.waiting-screen")
local GameScreen = require("game.game-screen")

---@class GameDataRp: RemoteProcedure
local GameDataRp = class("GameDataRp", RemoteProcedure)

local function ListRequiredAssets()
    local list = {}
    local data = app.data
    local page = data.pages[data.game.page]
    table.insert(list, page.image)
    for _, v in ipairs(page.tokens) do
        table.insert(list, data.tokens[v].avatar)
    end
    return list
end

function GameDataRp:init(connection)
    RemoteProcedure.init(self, connection)
end

function GameDataRp:send_response()
    return {
        data = app.data
    }
end

function GameDataRp:receive_response(response)
    app.data = response.data
    app.screen_manager:show(WaitingScreen("Synchronizing Assets..."))
    local list = ListRequiredAssets()
    app.asset_manager:download_missing_assets(list, function()
        app.screen_manager:show(GameScreen(app.data.game))
    end)
end

return GameDataRp

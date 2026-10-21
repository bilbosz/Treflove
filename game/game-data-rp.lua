local RemoteProcedure = require("networking.remote-procedure")
local WaitingScreen = require("screens.waiting-screen")

---@class GameData The persisted game state (`server/save.lua`), served whole by `GameDataRp`
---@field game GameScreenData
---@field pages table<string, PageData> By page name
---@field token_properties table<string, TokenProperty> By token data key
---@field tokens table<string, TokenData> By token name, as `PageData.tokens` lists them
---@field players table<string, PlayerData> By login

---@class GameScreenData The `game` entry, the model of the game screen
---@field page string The shown page, a key of `GameData.pages`

---@alias TokenPropertyType "string"|"number"|"image"|"array"

---@class TokenProperty
---@field title string Shown in the token panel
---@field type TokenPropertyType

---@alias PlayerGroup "master"|"player"

---@class PlayerData
---@field name string Display name
---@field auth string The login's server-side hash of the client hash
---@field group PlayerGroup

---@class GameDataResponse
---@field public data GameData

---@class GameDataRp: RemoteProcedure
local GameDataRp = class("GameDataRp", RemoteProcedure)

---@return string[] Asset paths required by the current page
local function _list_required_assets()
    local list = {}
    local data = assert(app.data)
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
        data = assert(app.data)
    }
end

---@param response GameDataResponse
function GameDataRp:receive_response(response)
    app.data = response.data
    app.screen_manager:show(WaitingScreen("Synchronizing Assets..."))
    local list = _list_required_assets()
    app.asset_manager:download_missing_assets(list, function()
        app.session:enter_game()
    end)
end

return GameDataRp

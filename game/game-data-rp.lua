local RemoteProcedure = require("networking.remote-procedure")
local WaitingScreen = require("screens.waiting-screen")
local permissions = require("game.permissions")

---@class GameData The persisted game state (`server/save.lua`), served by `GameDataRp`, filtered by what the session may read
---@field game GameScreenData
---@field pages table<string, PageData> By page name
---@field token_properties table<string, TokenProperty> By token data key
---@field tokens table<string, TokenData> By token name, as `PageData.tokens` lists them
---@field players table<string, PlayerData> By login
---@field groups table<string, GroupData> By group name, as `PlayerData.group` names them

---@class GameScreenData The `game` entry, the model of the game screen
---@field page string The shown page, a key of `GameData.pages`

---@alias TokenPropertyType "string"|"number"|"image"|"array"

---@class TokenProperty
---@field title string Shown in the token panel
---@field type TokenPropertyType

---@class GroupData
---@field title string Display name
---@field permissions string[] Grants of every player in the group, `<action>[:<kind>[/<key>]]` (`game/permissions.lua`)

---@class PlayerData
---@field name string Display name
---@field auth string|nil The login's server-side hash of the client hash; on the server only, the wire copy has none
---@field group string A key of `GameData.groups`
---@field permissions string[]|nil Grants of the player's own, added to the group's

---@class GameDataResponse: ResponseBody
---@field public data GameData What the session's permissions read (`permissions.filter`)
---@field public permissions string[] The session's grants, as `PermissionSet:get_grants` gives them

---@class GameDataRp: RemoteProcedure
---@field private _session Session
local GameDataRp = class("GameDataRp", RemoteProcedure)

---@param data GameData
---@return PageData|nil The shown page, `nil` when the data has none the user may read
local function _get_shown_page(data)
    local name = data.game.page
    return name and data.pages[name]
end

---@param data GameData
---@param page PageData
---@return string[] Asset paths required by the page
local function _list_required_assets(data, page)
    local list = {}
    table.insert(list, page.image)
    for _, v in ipairs(page.tokens) do
        local token = data.tokens[v]
        if token and token.avatar then
            table.insert(list, token.avatar)
        end
    end
    return list
end

---@param session Session
function GameDataRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@return GameDataResponse
function GameDataRp:send_response()
    assert(app.is_server)
    local set = self._session:get_permissions()
    return {
        data = permissions.filter(assert(app.data), set),
        permissions = set:get_grants()
    }
end

---@param response GameDataResponse
function GameDataRp:receive_response(response)
    assert(app.is_client)
    local session = self._session
    if not session:is_logged_in() then -- the data answered a login that is over
        return
    end
    app.data = response.data
    session:set_grants(response.permissions)
    local page = _get_shown_page(response.data)
    if not page then
        app.notification_manager:notify("Nothing to show: no page you may see")
        session:show_menu()
        return
    end
    app.screen_manager:show(WaitingScreen("Synchronizing Assets..."))
    app.asset_manager:download_missing_assets(_list_required_assets(response.data, page), function()
        session:enter_game()
    end)
end

return GameDataRp

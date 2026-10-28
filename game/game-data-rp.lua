local RemoteProcedure = require("networking.remote-procedure")
local WaitingScreen = require("screens.waiting-screen")
local permissions = require("game.permissions")

---@class GameData The persisted state of one game (`s/games/<id>/save.lua`), served by `GameDataRp`, filtered by what the session may read
---@field name string The game's display name
---@field game GameScreenData
---@field pages table<string, PageData> By page name
---@field token_properties table<string, TokenProperty> By token data key
---@field tokens table<string, TokenData> By token id: the key the pages' token lists and the grants name
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

---@class PlayerData One account's part in a game: the account holds its name and its auth
---@field group string A key of `GameData.groups`
---@field permissions string[]|nil Grants of the player's own, added to the group's

---@class GameDataRequest: RequestBody
---@field public game string The id of the game to join

---@class GameDataResponse: ResponseBody
---@field public success boolean `false` when the game cannot be joined: no data then
---@field public error string|nil Why not, for the user
---@field public game string The id of the game asked for
---@field public data GameData|nil What the session's permissions read (`permissions.filter`)
---@field public permissions string[]|nil The session's grants, as `PermissionSet:get_grants` gives them

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
---@return string[] Asset paths required by the page: its image and the avatars of its tokens
function GameDataRp.list_required_assets(data, page)
    ---@type string[]
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

---@param request GameDataRequest
---@return GameDataResponse
function GameDataRp:send_response(request)
    assert(app.is_server)
    local session = self._session
    if not session:is_logged_in() then
        return {
            success = false,
            error = "Not logged in",
            game = request.game
        }
    end
    local ok, err = session:select_game(request.game)
    if not ok then
        return {
            success = false,
            error = err,
            game = request.game
        }
    end
    local set = session:get_permissions()
    return {
        success = true,
        game = request.game,
        data = permissions.filter(session:get_game():get_data(), set),
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
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot join the game")
        session:show_menu()
        return
    end
    local data = assert(response.data)
    session:set_game_data(response.game, data, assert(response.permissions))
    local page = _get_shown_page(data)
    if not page then
        app.notification_manager:notify("Nothing to show: no page you may see")
        session:show_menu()
        return
    end
    app.screen_manager:show(WaitingScreen("Synchronizing Assets..."))
    app.asset_manager:download_missing_assets(GameDataRp.list_required_assets(data, page), function()
        session:enter_game()
    end)
end

return GameDataRp

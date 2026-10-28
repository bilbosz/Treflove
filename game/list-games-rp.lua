local RemoteProcedure = require("networking.remote-procedure")
local permissions = require("game.permissions")

---@class ListGamesRequest: RequestBody

---@class ListGamesResponse: ResponseBody
---@field public games GameInfo[] Every game on the server, by name, then by id; none for a session that is not logged in

---@class ListGamesRp: RemoteProcedure
---@field private _session Session
local ListGamesRp = class("ListGamesRp", RemoteProcedure)

---@param a GameInfo
---@param b GameInfo
---@return boolean
local function _by_name_then_id(a, b)
    if a.name ~= b.name then
        return a.name < b.name
    end
    return a.id < b.id
end

---@param session Session
function ListGamesRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request ListGamesRequest
---@return ListGamesResponse
function ListGamesRp:send_response(request)
    assert(app.is_server)
    ---@type GameInfo[]
    local games = {}
    local user = self._session:get_user()
    if user then
        local all = assert(app.games)
        for _, id in ipairs(all:list()) do
            local game = assert(all:get(id))
            table.insert(games, {
                id = id,
                name = game:get_name(),
                member = game:get_data().players[user] ~= nil,
                deletable = game:allows(user, permissions.Action.WRITE, permissions.Kind.GAME)
            })
        end
        table.sort(games, _by_name_then_id)
    end
    return {
        games = games
    }
end

---@param response ListGamesResponse
function ListGamesRp:receive_response(response)
    assert(app.is_client)
end

return ListGamesRp

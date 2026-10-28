local RemoteProcedure = require("networking.remote-procedure")
local permissions = require("game.permissions")

---@class DeleteGameRequest: RequestBody
---@field public id string The game's id, as `ListGamesRp` lists it

---@class DeleteGameResponse: ResponseBody
---@field public success boolean
---@field public id string|nil The deleted game's, on success
---@field public name string|nil The deleted game's, on success
---@field public error string|nil Why not, for the user

---@class DeleteGameRp: RemoteProcedure
---@field private _session Session
local DeleteGameRp = class("DeleteGameRp", RemoteProcedure)

---@param session Session
function DeleteGameRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param error string
---@return DeleteGameResponse
local function _refusal(error)
    return {
        success = false,
        error = error
    }
end

---@param request DeleteGameRequest
---@return DeleteGameResponse
function DeleteGameRp:send_response(request)
    assert(app.is_server)
    local user = self._session:get_user()
    if not user then
        return _refusal("Not logged in")
    end
    local games = assert(app.games)
    local game = games:get(request.id)
    if not game then
        return _refusal("No such game")
    end
    if not game:allows(user, permissions.Action.WRITE, permissions.Kind.GAME) then
        return _refusal(string.format("You may not delete the game %q", game:get_name()))
    end
    local id, name = game:get_id(), game:get_name()
    for _, session in ipairs(game:get_sessions()) do
        session:deselect_game()
        if session ~= self._session then
            session:get_game_deleted_rp():send_request({
                id = id,
                name = name
            })
        end
    end
    games:delete(id)
    return {
        success = true,
        id = id,
        name = name
    }
end

---@param response DeleteGameResponse
function DeleteGameRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot delete the game")
    end
end

return DeleteGameRp

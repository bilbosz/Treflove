local RemoteProcedure = require("networking.remote-procedure")

---@class CreateGameRequest: RequestBody
---@field public name string

---@class CreateGameResponse: ResponseBody
---@field public success boolean
---@field public id string|nil The new game's, on success
---@field public error string|nil Why not, for the user

---@class CreateGameRp: RemoteProcedure
---@field private _session Session
local CreateGameRp = class("CreateGameRp", RemoteProcedure)

---@param session Session
function CreateGameRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request CreateGameRequest
---@return CreateGameResponse
function CreateGameRp:send_response(request)
    assert(app.is_server)
    local user = self._session:get_user()
    if not user then
        return {
            success = false,
            error = "Not logged in"
        }
    end
    local game, err = assert(app.games):create(request.name, user)
    if not game then
        return {
            success = false,
            error = err
        }
    end
    return {
        success = true,
        id = game:get_id()
    }
end

---@param response CreateGameResponse
function CreateGameRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot create the game")
    end
end

return CreateGameRp

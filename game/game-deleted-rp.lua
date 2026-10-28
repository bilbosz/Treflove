local RemoteProcedure = require("networking.remote-procedure")

---@class GameDeletedRequest: RequestBody
---@field public id string The deleted game's
---@field public name string The deleted game's

---@class GameDeletedResponse: ResponseBody An acknowledgement, nothing in it

---@class GameDeletedRp: RemoteProcedure
---@field private _session Session
local GameDeletedRp = class("GameDeletedRp", RemoteProcedure)

---@param session Session
function GameDeletedRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request GameDeletedRequest
---@return GameDeletedResponse
function GameDeletedRp:send_response(request)
    if not app.is_client then
        app:log("GameDeletedRp is the server's to send: a request from the client ignored")
        return {}
    end
    self._session:apply_game_deleted(request.id, request.name)
    return {}
end

---@param response GameDeletedResponse
function GameDeletedRp:receive_response(response)
end

return GameDeletedRp

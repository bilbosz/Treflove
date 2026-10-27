local RemoteProcedure = require("networking.remote-procedure")

---@class TokenDeletedRequest: RequestBody
---@field public id string The deleted token's id

---@class TokenDeletedResponse: ResponseBody An acknowledgement, nothing in it

---@class TokenDeletedRp: RemoteProcedure
---@field private _session Session
local TokenDeletedRp = class("TokenDeletedRp", RemoteProcedure)

---@param session Session
function TokenDeletedRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request TokenDeletedRequest
---@return TokenDeletedResponse
function TokenDeletedRp:send_response(request)
    if not app.is_client then
        app:log("TokenDeletedRp is the server's to send: a request from the client ignored")
        return {}
    end
    self._session:apply_token_deleted(request.id)
    return {}
end

---@param response TokenDeletedResponse
function TokenDeletedRp:receive_response(response)
end

return TokenDeletedRp

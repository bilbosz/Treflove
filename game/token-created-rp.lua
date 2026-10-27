local RemoteProcedure = require("networking.remote-procedure")

---@class TokenCreatedRequest: RequestBody
---@field public id string The new token's id
---@field public page string The page it is placed on
---@field public token TokenData The server's entry

---@class TokenCreatedResponse: ResponseBody An acknowledgement, nothing in it

---@class TokenCreatedRp: RemoteProcedure
---@field private _session Session
local TokenCreatedRp = class("TokenCreatedRp", RemoteProcedure)

---@param session Session
function TokenCreatedRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request TokenCreatedRequest
---@return TokenCreatedResponse
function TokenCreatedRp:send_response(request)
    if not app.is_client then
        app:log("TokenCreatedRp is the server's to send: a request from the client ignored")
        return {}
    end
    self._session:apply_token_created(request.id, request.page, request.token)
    return {}
end

---@param response TokenCreatedResponse
function TokenCreatedRp:receive_response(response)
end

return TokenCreatedRp

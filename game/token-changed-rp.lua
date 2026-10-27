local RemoteProcedure = require("networking.remote-procedure")

---@class TokenChangedRequest: RequestBody
---@field public id string The token's id before the change
---@field public new_id string|nil Its id after a rename
---@field public token TokenData The server's entry after the change (under `new_id` when renamed)

---@class TokenChangedResponse: ResponseBody An acknowledgement, nothing in it

---@class TokenChangedRp: RemoteProcedure
---@field private _session Session
local TokenChangedRp = class("TokenChangedRp", RemoteProcedure)

---@param session Session
function TokenChangedRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request TokenChangedRequest
---@return TokenChangedResponse
function TokenChangedRp:send_response(request)
    if app.is_server then
        app:log("TokenChangedRp is the server's to send: a request from the client ignored")
        return {}
    end
    local data = app.data
    if not data or not data.tokens[request.id] then
        app:log(string.format("A change of the token %q, which this client does not hold, ignored", tostring(request.id)))
        return {}
    end
    self._session:apply_token(request.id, request.new_id, request.token)
    return {}
end

---@param response TokenChangedResponse
function TokenChangedRp:receive_response(response)
end

return TokenChangedRp

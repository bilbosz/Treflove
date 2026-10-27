local RemoteProcedure = require("networking.remote-procedure")

---@class GrantsChangedRequest: RequestBody
---@field public permissions string[] The session's grants, as `PermissionSet:get_grants` gives them

---@class GrantsChangedResponse: ResponseBody An acknowledgement, nothing in it

---@class GrantsChangedRp: RemoteProcedure
---@field private _session Session
local GrantsChangedRp = class("GrantsChangedRp", RemoteProcedure)

---@param session Session
function GrantsChangedRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request GrantsChangedRequest
---@return GrantsChangedResponse
function GrantsChangedRp:send_response(request)
    if not app.is_client then
        app:log("GrantsChangedRp is the server's to send: a request from the client ignored")
        return {}
    end
    self._session:apply_grants(request.permissions)
    return {}
end

---@param response GrantsChangedResponse
function GrantsChangedRp:receive_response(response)
end

return GrantsChangedRp

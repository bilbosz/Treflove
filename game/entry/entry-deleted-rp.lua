local RemoteProcedure = require("networking.remote-procedure")

---@class EntryDeletedRequest: RequestBody
---@field public kind EntryKind
---@field public id string The deleted entry's id

---@class EntryDeletedResponse: ResponseBody An acknowledgement, nothing in it

---@class EntryDeletedRp: RemoteProcedure
---@field private _session Session
local EntryDeletedRp = class("EntryDeletedRp", RemoteProcedure)

---@param session Session
function EntryDeletedRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request EntryDeletedRequest
---@return EntryDeletedResponse
function EntryDeletedRp:send_response(request)
    if not app.is_client then
        app:log("EntryDeletedRp is the server's to send: a request from the client ignored")
        return {}
    end
    self._session:apply_entry_deleted(request.kind, request.id)
    return {}
end

---@param response EntryDeletedResponse
function EntryDeletedRp:receive_response(response)
end

return EntryDeletedRp

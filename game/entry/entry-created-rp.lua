local RemoteProcedure = require("networking.remote-procedure")

---@class EntryCreatedRequest: RequestBody
---@field public kind EntryKind
---@field public id string The new entry's id
---@field public entry EntryData The server's entry

---@class EntryCreatedResponse: ResponseBody An acknowledgement, nothing in it

---@class EntryCreatedRp: RemoteProcedure
---@field private _session Session
local EntryCreatedRp = class("EntryCreatedRp", RemoteProcedure)

---@param session Session
function EntryCreatedRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request EntryCreatedRequest
---@return EntryCreatedResponse
function EntryCreatedRp:send_response(request)
    if not app.is_client then
        app:log("EntryCreatedRp is the server's to send: a request from the client ignored")
        return {}
    end
    self._session:apply_entry_created(request.kind, request.id, request.entry)
    return {}
end

---@param response EntryCreatedResponse
function EntryCreatedRp:receive_response(response)
end

return EntryCreatedRp

local RemoteProcedure = require("networking.remote-procedure")

---@class EntryChangedRequest: RequestBody
---@field public kind EntryKind
---@field public id string The entry's id before the change
---@field public new_id string|nil Its id after a rename
---@field public entry EntryData The server's entry after the change (under `new_id` when renamed)

---@class EntryChangedResponse: ResponseBody An acknowledgement, nothing in it

---@class EntryChangedRp: RemoteProcedure
---@field private _session Session
local EntryChangedRp = class("EntryChangedRp", RemoteProcedure)

---@param session Session
function EntryChangedRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request EntryChangedRequest
---@return EntryChangedResponse
function EntryChangedRp:send_response(request)
    if not app.is_client then
        app:log("EntryChangedRp is the server's to send: a request from the client ignored")
        return {}
    end
    self._session:apply_entry(request.kind, request.id, request.new_id, request.entry)
    return {}
end

---@param response EntryChangedResponse
function EntryChangedRp:receive_response(response)
end

return EntryChangedRp

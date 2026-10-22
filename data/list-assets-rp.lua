local Asset = require("data.asset")
local RemoteProcedure = require("networking.remote-procedure")
local permissions = require("game.permissions")

---@class ListAssetsRequest: RequestBody

---@class ListAssetsResponse: ResponseBody
---@field public success boolean `false` when the session may not read the assets: no entries then
---@field public entries AssetEntry[]|nil The whole store, parents before their content
---@field public writable boolean Whether the session may change the store: upload, make folders, rename, delete

---@class ListAssetsRp: RemoteProcedure
---@field private _session Session
local ListAssetsRp = class("ListAssetsRp", RemoteProcedure)

---@param session Session
function ListAssetsRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request ListAssetsRequest
---@return ListAssetsResponse
function ListAssetsRp:send_response(request)
    assert(app.is_server)
    local session = self._session
    if not session:is_allowed(permissions.Action.READ, permissions.Kind.ASSETS) then
        return {
            success = false,
            writable = false
        }
    end
    return {
        success = true,
        entries = Asset.list(),
        writable = session:is_allowed(permissions.Action.WRITE, permissions.Kind.ASSETS)
    }
end

---@param response ListAssetsResponse
function ListAssetsRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify("Not allowed to browse assets")
    end
end

return ListAssetsRp

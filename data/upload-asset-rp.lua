local RemoteProcedure = require("networking.remote-procedure")
local permissions = require("game.permissions")

---@class UploadAssetRequest: RequestBody
---@field public path string
---@field public content string

---@class UploadAssetResponse: ResponseBody
---@field public success boolean `false` when the session may not write assets: nothing was written

---@class UploadAssetRp: RemoteProcedure
---@field private _session Session
local UploadAssetRp = class("UploadAssetRp", RemoteProcedure)

---@param session Session
function UploadAssetRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request UploadAssetRequest
---@return UploadAssetResponse
function UploadAssetRp:send_response(request)
    assert(app.is_server)
    local session = self._session
    if not session:is_logged_in() or not session:get_permissions():allows(permissions.Action.WRITE, permissions.Kind.ASSETS) then
        return {
            success = false
        }
    end
    app.asset_manager:mount_file(request.path, request.content)
    return {
        success = true
    }
end

---@param response UploadAssetResponse
function UploadAssetRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify("Not allowed to upload assets")
    end
end

return UploadAssetRp

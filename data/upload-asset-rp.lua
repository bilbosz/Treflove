local RemoteProcedure = require("networking.remote-procedure")
local permissions = require("game.permissions")

---@class UploadAssetRequest: RequestBody
---@field public path string
---@field public content string

---@class UploadAssetResponse: ResponseBody
---@field public success boolean `false` when the session may not write assets, or the path cannot take a file: nothing was written
---@field public error string|nil Why not, for the user, when the path is the problem

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
    if not self._session:is_allowed(permissions.Action.WRITE, permissions.Kind.ASSETS) then
        return {
            success = false
        }
    end
    local ok, err = self._session:get_game():get_store():mount_file(request.path, request.content)
    return {
        success = ok,
        error = err
    }
end

---@param response UploadAssetResponse
function UploadAssetRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Not allowed to upload assets")
    end
end

return UploadAssetRp

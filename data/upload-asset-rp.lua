local RemoteProcedure = require("networking.remote-procedure")

---@class UploadAssetRequest
---@field public path string
---@field public content string

---@class UploadAssetResponse
---@field public success boolean

---@class UploadAssetRp: RemoteProcedure
local UploadAssetRp = class("UploadAssetRp", RemoteProcedure)

---@param connection Connection
function UploadAssetRp:init(connection)
    RemoteProcedure.init(self, connection)
end

---@param request UploadAssetRequest
---@return UploadAssetResponse
function UploadAssetRp:send_response(request)
    assert(app.is_server)
    app.asset_manager:mount_file(request.path, request.content)
    return {
        success = true
    }
end

---@param response UploadAssetResponse
function UploadAssetRp:receive_response(response)
    assert(app.is_client)
    assert(response.success)
end

return UploadAssetRp

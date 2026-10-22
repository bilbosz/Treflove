local RemoteProcedure = require("networking.remote-procedure")

---@class DownloadAssetRequest: RequestBody
---@field public path string

---@class DownloadAssetResponse: ResponseBody
---@field public path string
---@field public content string|nil `nil` when the server has no such asset

---@class DownloadAssetRp: RemoteProcedure
local DownloadAssetRp = class("DownloadAssetRp", RemoteProcedure)

---@param connection Connection
function DownloadAssetRp:init(connection)
    RemoteProcedure.init(self, connection)
end

---@param request DownloadAssetRequest
---@return DownloadAssetResponse
function DownloadAssetRp:send_response(request)
    assert(app.is_server)
    return {
        path = request.path,
        content = app.asset_manager:get_content(request.path)
    }
end

---@param response DownloadAssetResponse
function DownloadAssetRp:receive_response(response)
    assert(app.is_client)
    if response.content then
        app.asset_manager:mount_file(response.path, response.content)
    end
end

return DownloadAssetRp

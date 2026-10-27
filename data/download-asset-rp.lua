local RemoteProcedure = require("networking.remote-procedure")

---@class DownloadAssetRequest: RequestBody
---@field public path string

---@class DownloadAssetResponse: ResponseBody
---@field public path string
---@field public content string|nil `nil` when the server has no such asset

---@class DownloadAssetRp: RemoteProcedure
---@field private _session Session
local DownloadAssetRp = class("DownloadAssetRp", RemoteProcedure)

---@param session Session
function DownloadAssetRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request DownloadAssetRequest
---@return DownloadAssetResponse
function DownloadAssetRp:send_response(request)
    assert(app.is_server)
    local session = self._session
    return {
        path = request.path,
        content = session:is_in_game() and session:get_game():get_store():get_content(request.path) or nil
    }
end

---@param response DownloadAssetResponse
function DownloadAssetRp:receive_response(response)
    assert(app.is_client)
    if response.content then
        assert(app.asset_manager:get_store()):mount_file(response.path, response.content)
    end
end

return DownloadAssetRp

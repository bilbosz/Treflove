local RemoteProcedure = require("networking.remote-procedure")

---@class DownloadMissingAssetsRequest
---@field public list string[]

---@class DownloadMissingAssetsResponse
---@field public success boolean
---@field public contents table<string, string>

---@class DownloadMissingAssetsRp: RemoteProcedure
local DownloadMissingAssetsRp = class("DownloadMissingAssetsRp", RemoteProcedure)

---@param connection Connection
function DownloadMissingAssetsRp:init(connection)
    RemoteProcedure.init(self, connection)
end

---@param request DownloadMissingAssetsRequest
---@return DownloadMissingAssetsResponse
function DownloadMissingAssetsRp:send_response(request)
    assert(app.is_server)
    local contents = {}
    for _, v in ipairs(request.list) do
        contents[v] = app.asset_manager:get_content(v)
    end
    return {
        success = true,
        contents = contents
    }
end

---@param response DownloadMissingAssetsResponse
function DownloadMissingAssetsRp:receive_response(response)
    assert(app.is_client)
    assert(response.success)
    assert(response.contents)
    for k, v in pairs(response.contents) do
        app.asset_manager:mount_file(k, v)
    end
end

return DownloadMissingAssetsRp

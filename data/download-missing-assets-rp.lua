local RemoteProcedure = require("networking.remote-procedure")

---@class DownloadMissingAssetsRequest: RequestBody
---@field public list string[]

---@class DownloadMissingAssetsResponse: ResponseBody
---@field public success boolean
---@field public contents table<string, string> Base64 contents by asset path, the paths the server has

---@class DownloadMissingAssetsRp: RemoteProcedure
---@field private _session Session
local DownloadMissingAssetsRp = class("DownloadMissingAssetsRp", RemoteProcedure)

---@param session Session
function DownloadMissingAssetsRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request DownloadMissingAssetsRequest
---@return DownloadMissingAssetsResponse
function DownloadMissingAssetsRp:send_response(request)
    assert(app.is_server)
    ---@type table<string, string>
    local contents = {}
    local session = self._session
    if session:is_in_game() then
        local store = session:get_game():get_store()
        for _, v in ipairs(request.list) do
            contents[v] = store:get_content(v)
        end
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
    local store = assert(app.asset_manager:get_store())
    for k, v in pairs(response.contents) do
        store:mount_file(k, v)
    end
end

return DownloadMissingAssetsRp

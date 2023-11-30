local RemoteProcedure = require("networking.remote-procedure")

---@class DownloadAssetRp: RemoteProcedure
local DownloadAssetRp = class("DownloadAssetRp", RemoteProcedure)

function DownloadAssetRp:init(connection)
    RemoteProcedure.init(self, connection)
end

function DownloadAssetRp:send_response(request)
    assert(app.is_server)
    return {
        path = request.path,
        content = app.asset_manager:get_content(request.path)
    }
end

function DownloadAssetRp:receive_response(response)
    assert(app.is_client)
    assert(response.content)
    app.asset_manager:mount_file(response.path, response.content)
end

return DownloadAssetRp

local RemoteProcedure = require("networking.remote-procedure")

---@class UploadAssetRp: RemoteProcedure
local UploadAssetRp = class("UploadAssetRp", RemoteProcedure)

function UploadAssetRp:init(connection)
    RemoteProcedure.init(self, connection)
end

function UploadAssetRp:send_response(request)
    assert(app.is_server)
    app.asset_manager:mount_file(request.path, request.content)
    return {
        success = true
    }
end

function UploadAssetRp:receive_response(response)
    assert(app.is_client)
    assert(response.success)
end

return UploadAssetRp

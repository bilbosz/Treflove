DownloadMissingAssetsRp = {}

function DownloadMissingAssetsRp:Init(connection)
    RemoteProcedure.Init(self, connection)
end

function DownloadMissingAssetsRp:SendResponse(request)
    assert(app.isServer)
    local contents = {}
    for _, v in ipairs(request.list) do
        contents[v] = app.assetManager:GetContent(v)
    end
    return {
        success = true,
        contents = contents
    }
end

function DownloadMissingAssetsRp:ReceiveResponse(response)
    assert(app.isClient)
    assert(response.success)
    assert(response.contents)
    for k, v in pairs(response.contents) do
        app.assetManager:MountFile(k, v)
    end
end

MakeClassOf(DownloadMissingAssetsRp, RemoteProcedure)

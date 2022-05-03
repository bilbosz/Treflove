DownloadAssetRp = {}

function DownloadAssetRp:Init(connection)
    RemoteProcedure.Init(self, connection)
end

function DownloadAssetRp:SendResponse(request)
    assert(app.isServer)
    return {
        path = request.path,
        content = app.assetManager:GetContent(request.path)
    }
end

function DownloadAssetRp:ReceiveResponse(response)
    assert(app.isClient)
    assert(response.content)
    app.assetManager:MountFile(response.path, response.content)
end

MakeClassOf(DownloadAssetRp, RemoteProcedure)

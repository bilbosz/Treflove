UploadAssetRp = {}

function UploadAssetRp:Init(connection)
    RemoteProcedure.Init(self, connection)
end

function UploadAssetRp:SendResponse(request)
    assert(app.isServer)
    app.assetManager:MountFile(request.path, request.content)
    return {
        success = true
    }
end

function UploadAssetRp:ReceiveResponse(response)
    assert(app.isClient)
    assert(response.success)
end

MakeClassOf(UploadAssetRp, RemoteProcedure)

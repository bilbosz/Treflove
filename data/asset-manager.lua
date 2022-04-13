AssetManager = {}

function AssetManager:Init()
    -- remote procedures by session
    self.uploadAssetRp = {}
    self.downloadAssetRp = {}
end

function AssetManager:MountFile(mountPoint, content)
    local file = File("assets/" .. mountPoint)
    if not file:GetType() then
        file:Create()
    end
    file:Write(love.data.decode("string", "base64", content))
end

function AssetManager:GetContent(path)
    local file = File("assets/" .. path)
    if file:GetType() ~= "file" then
        return nil
    end
    return love.data.encode("string", "base64", file:Read(), file:GetSize())
end

function AssetManager:UploadAsset(path, file)
    assert(app.isClient)
    file:open("r")

    local rp = select(2, next(self.uploadAssetRp))
    rp:SendRequest({
        path = path,
        content = love.data.encode("string", "base64", file:read(), file:getSize())
    })

    file:close()
end

function AssetManager:DownloadAsset(path)
    assert(app.isClient)

    local rp = select(2, next(self.downloadAssetRp))
    rp:SendRequest({
        path = path
    })
end

function AssetManager:RegisterSession(session)
    local connection = session:GetConnection()
    self.uploadAssetRp[session] = UploadAssetRp(connection)
    self.downloadAssetRp[session] = DownloadAssetRp(connection)
end

function AssetManager:UnregisterSession(session)
    self.uploadAssetRp[session]:Release()
    self.uploadAssetRp[session] = nil

    self.downloadAssetRp[session]:Release()
    self.downloadAssetRp[session] = nil
end

MakeClassOf(AssetManager)

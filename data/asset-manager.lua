AssetManager = {}

local function FilterForMissingAssets(list)
    for i, v in ripairs(list) do
        if Asset(v):GetType() then
            table.remove(list, i)
        end
    end
end

local function GetAnyRp(rpList)
    return select(2, next(rpList))
end

local function RemoveServerMount(path)
    local info = love.filesystem.getInfo(path)
    if not info then
        return
    end
    if info.type == "file" then
        love.filesystem.remove(path)
    elseif info.type == "directory" then
        local items = love.filesystem.getDirectoryItems(path)
        for _, v in ipairs(items) do
            RemoveServerMount(path .. "/" .. v)
        end
        love.filesystem.remove(path)
    else
        assert(false)
    end
end

local function MountServerAssets(srcPath, dstPath)
    local srcInfo = love.filesystem.getInfo(srcPath)
    if srcInfo.type == "file" then
        local data = love.filesystem.read(srcPath)
        love.filesystem.write(dstPath, data)
    elseif srcInfo.type == "directory" then
        love.filesystem.createDirectory(dstPath)
        local items = love.filesystem.getDirectoryItems(srcPath)
        for _, v in ipairs(items) do
            MountServerAssets(srcPath .. "/" .. v, dstPath .. "/" .. v)
        end
    else
        assert(false)
    end
end

function AssetManager:Init()
    -- remote procedures by session
    if app.isServer then
        RemoveServerMount("s")
        MountServerAssets("server", "s")
    end
    self.uploadAssetRp = {}
    self.downloadAssetRp = {}
    self.downloadMissingAssetsRp = {}
end

function AssetManager:MountFile(mountPoint, content)
    local file = Asset(mountPoint)
    if not file:GetType() then
        file:Create()
    end
    file:Write(love.data.decode("string", "base64", content))
end

function AssetManager:GetContent(path)
    local file = Asset(path)
    if file:GetType() ~= "file" then
        return nil
    end
    return love.data.encode("string", "base64", file:Read(), file:GetSize())
end

function AssetManager:UploadAsset(path, data, dataSize)
    assert(app.isClient)

    local rp = GetAnyRp(self.uploadAssetRp)
    rp:SendRequest({
        path = path,
        content = love.data.encode("string", "base64", data, dataSize)
    })
end

function AssetManager:DownloadAsset(path)
    assert(app.isClient)

    local rp = GetAnyRp(self.downloadAssetRp)
    rp:SendRequest({
        path = path
    })
end

function AssetManager:DownloadMissingAssets(list, cb)
    FilterForMissingAssets(list)

    local rp = GetAnyRp(self.downloadMissingAssetsRp)
    rp:SendRequest({
        list = list
    }, cb)
end

function AssetManager:RegisterSession(session)
    local connection = session:GetConnection()
    self.uploadAssetRp[session] = UploadAssetRp(connection)
    self.downloadAssetRp[session] = DownloadAssetRp(connection)
    self.downloadMissingAssetsRp[session] = DownloadMissingAssetsRp(connection)
end

function AssetManager:UnregisterSession(session)
    self.uploadAssetRp[session]:Release()
    self.uploadAssetRp[session] = nil

    self.downloadAssetRp[session]:Release()
    self.downloadAssetRp[session] = nil

    self.downloadMissingAssetsRp[session]:Release()
    self.downloadMissingAssetsRp[session] = nil
end

MakeClassOf(AssetManager)

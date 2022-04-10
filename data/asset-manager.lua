AssetManager = {}

local function MountFile(mountPoint, content)
    local file = File(mountPoint)
    if not file:GetType() then
        file:Create()
    end
    file:Write(love.data.decode("string", "base64", content))
end

function AssetManager:Init()
    self.sessions = {}
end

function AssetManager:UploadAsset(file, path)
    assert(app.isClient)
    file:open("r")
    local encoded = love.data.encode("string", "base64", file:read(), file:getSize())
    file:close()
    local session = next(self.sessions)
    local connection = session:GetConnection()
    connection:SendRequest("upload-asset", {
        path = path,
        content = encoded
    }, function(response)
        assert(response.success)
    end)
end

function AssetManager:DownloadAsset(path)
    assert(app.isClient)
    local session = next(self.sessions)
    local connection = session:GetConnection()
    connection:SendRequest("download-asset", {
        path = path
    }, function(response)
        assert(response.content)
        MountFile("assets/" .. path, response.content)
    end)
end

function AssetManager:RegisterSession(session)
    self.sessions[session] = true
    local connection = session:GetConnection()
    connection:RegisterRequestHandler("upload-asset", function(request)
        MountFile("assets/" .. request.path, request.content)
        return {
            success = true
        }
    end)
    connection:RegisterRequestHandler("download-asset", function(request)
        local file = File("assets/" .. request.path)
        if file:GetType() ~= "file" then
            return {}
        end
        local encoded = love.data.encode("string", "base64", file:Read(), file:GetSize())
        return {
            content = encoded
        }
    end)
end

function AssetManager:UnregisterSession(session)
    self.sessions[session] = nil
end

MakeClassOf(AssetManager)

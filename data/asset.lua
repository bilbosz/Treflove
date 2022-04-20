Asset = {}

local function CreateIntermediateDirs(path)
    local found = 0
    while true do
        found = string.find(path, "/", found + 1)
        if not found then
            break
        end
        local dir = string.sub(path, 1, found - 1)
        local info = love.filesystem.getInfo(dir)
        if not info then
            assert(love.filesystem.createDirectory(dir))
        else
            assert(info.type == "directory")
        end
    end
end

function Asset.GetAssetPath(virtualPath)
    return (app.isServer and "server/assets/" or "client/assets/") .. virtualPath
end

function Asset.GetRootPath(virtualPath)
    return (app.isServer and "server/" or "client/") .. virtualPath
end

function Asset:Init(path, onRoot)
    assert(string.sub(path, 1, 1) ~= "/")
    self.path = onRoot and Asset.GetRootPath(path) or Asset.GetAssetPath(path)
end

function Asset:Create()
    CreateIntermediateDirs(self.path)
    assert(love.filesystem.write(self.path, ""))
end

function Asset:Write(content)
    assert(love.filesystem.write(self.path, content))
end

function Asset:Read()
    return love.filesystem.read(self.path)
end

function Asset:GetType()
    local info = love.filesystem.getInfo(self.path)
    return info and info.type
end

function Asset:GetSize()
    local info = love.filesystem.getInfo(self.path)
    return info and info.size
end

function Asset:GetPath()
    local info = love.filesystem.getInfo(self.path)
    return info and self.path
end

MakeClassOf(Asset)

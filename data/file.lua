File = {}

local function GetRealPath(virtualPath)
    return (app.isServer and "server/" or "client/") .. virtualPath
end

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

function File:Init(path)
    assert(string.sub(path, 1, 1) ~= "/")
    self.path = GetRealPath(path)
end

function File:Create()
    CreateIntermediateDirs(self.path)
    assert(love.filesystem.write(self.path, ""))
end

function File:Write(content)
    assert(love.filesystem.write(self.path, content))
end

function File:Read()
    return love.filesystem.read(self.path)
end

function File:GetType()
    local info = love.filesystem.getInfo(self.path)
    return info and info.type
end

function File:GetSize()
    local info = love.filesystem.getInfo(self.path)
    return info and info.size
end

MakeClassOf(File)

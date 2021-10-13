Loader = {
    cache = {},
    classFiles = {}
}

function Loader:LoadFile(path, force)
    local info = love.filesystem.getInfo(path)
    assert(info)
    assert(info.type == "file")
    local cache = self.cache[path]
    if not force and cache and info.modtime <= cache.modtime then
        return
    end
    local chunk, error = love.filesystem.load(path)
    assert(not error, error)
    self.cache[path] = {
        chunk = chunk,
        modtime = info.modtime
    }
    chunk()
end

function Loader:LoadDirectory(path, recursive, force)
    local info = love.filesystem.getInfo(path)
    assert(info)
    assert(info.type == "directory")
    for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
        local itemPath = path .. "/" .. item
        local info = love.filesystem.getInfo(itemPath)
        local n = #itemPath
        if info.type == "file" and string.sub(itemPath, n - 3, n) == ".lua" then
            self:LoadFile(itemPath, force)
        elseif recursive and info.type == "directory" then
            self:LoadDirectory(itemPath, recursive, force)
        end
    end
end

function Loader:LoadClass(path, force)
    self:LoadFile(path, force)
    self.classFiles[path] = true
end

function Loader:LoadModule(path, force)
    local info = love.filesystem.getInfo(path)
    assert(info)
    assert(info.type == "directory")
    for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
        local itemPath = path .. "/" .. item
        local info = love.filesystem.getInfo(itemPath)
        local n = #itemPath
        if info.type == "file" and string.sub(itemPath, n - 3, n) == ".lua" then
            self:LoadClass(itemPath, force)
        elseif info.type == "directory" and string.sub(itemPath, n - 4, n) ~= "/impl" then
            self:LoadModule(itemPath, force)
        end
    end
end

function Loader:ReloadClasses(force)
    local files = table.copy(self.classFiles)
    for k, v in pairs(files) do
        self:LoadFile(k, force)
    end
end

return Loader

Loader = {
    cache = {}
}

function Loader.LoadFile(path, force)
    local info = love.filesystem.getInfo(path)
    assert(info)
    assert(info.type == "file")
    local cache = Loader.cache[path]
    if not force and cache and info.modtime <= cache.modtime then
        return
    end
    local chunk, error = love.filesystem.load(path)
    assert(not error, error)
    Loader.cache[path] = {
        chunk = chunk,
        modtime = info.modtime
    }
    chunk()
end

function Loader.LoadDirectory(path, recursive, force)
    local info = love.filesystem.getInfo(path)
    assert(info)
    assert(info.type == "directory")
    for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
        local itemPath = path .. "/" .. item
        local info = love.filesystem.getInfo(itemPath)
        local n = #itemPath
        if info.type == "file" and string.sub(itemPath, n - 3, n) == ".lua" and item ~= "module.lua" then
            Loader.LoadFile(itemPath, force)
        elseif recursive and info.type == "directory" then
            Loader.LoadDirectory(itemPath, recursive, force)
        end
    end
end

function Loader.LoadModule(path, force)
    local info = love.filesystem.getInfo(path)
    if path == "." then
        Loader.LoadFile("module.lua", force)
    else
        assert(info)
        assert(info.type == "directory")
        Loader.LoadFile(path .. "/module.lua", force)
    end
end

function Loader.Reload(force)
    local files = table.copy(Loader.cache)
    for k in pairs(files) do
        Loader.LoadFile(k, force)
    end
end

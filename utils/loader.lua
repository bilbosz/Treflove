Loader = {}

function Loader:Load(path)
    return love.filesystem.load(path)()
end

function Loader:LoadOptional(path)
    local fileExists, chunk = pcall(love.filesystem.load, path)
    if not fileExists then
        return nil
    end
    local noError, result = pcall(chunk)
    if not noError then
        return nil
    end
    return result
end

return Loader

---@alias AssetEntryType "file"|"directory"
---@class AssetEntry One item of an asset store, as `AssetStore:list` and `ListAssetsRp` give it
---@field path string Relative to the store's assets, `/`-separated
---@field type AssetEntryType
---@field size number|nil Bytes, for a file
---@class Asset: Object
---@field private _path string
local Asset = class("Asset")

---@param path string
local function _create_intermediate_dirs(path)
    ---@type integer|nil
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

---@param src string
---@param dst string
local function _copy_tree(src, dst)
    local info = assert(love.filesystem.getInfo(src))
    if info.type == "file" then
        assert(love.filesystem.write(dst, (love.filesystem.read(src))))
    elseif info.type == "directory" then
        assert(love.filesystem.createDirectory(dst))
        for _, item in ipairs(love.filesystem.getDirectoryItems(src)) do
            _copy_tree(src .. "/" .. item, dst .. "/" .. item)
        end
    else
        assert_unreachable()
    end
end

---@param path string
local function _remove_tree(path)
    local info = love.filesystem.getInfo(path)
    if not info then
        return
    end
    if info.type == "directory" then
        for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
            _remove_tree(path .. "/" .. item)
        end
    elseif info.type ~= "file" then
        assert_unreachable()
    end
    assert(love.filesystem.remove(path))
end

---@param path string
---@return string|nil reason `nil` when the path is fine
function Asset.check_path(path)
    if type(path) ~= "string" or path == "" then
        return "an empty path"
    end
    if string.sub(path, 1, 1) == "/" then
        return "an absolute path"
    end
    if string.sub(path, -1) == "/" then
        return "a path ending with /"
    end
    for component in string.gmatch(path .. "/", "([^/]*)/") do
        if component == "" then
            return "an empty name"
        end
        if component == "." or component == ".." then
            return string.format("the name %q", component)
        end
    end
    return nil
end

---@param path string
---@return string The last component
function Asset.get_name(path)
    return (string.match(path, "([^/]*)$"))
end

---@param path string
---@return string The path without its last component, `""` at the root
function Asset.get_parent(path)
    return string.match(path, "^(.*)/[^/]*$") or ""
end

---@param dir string `""` for the root
---@param name string
---@return string
function Asset.join(dir, name)
    if dir == "" then
        return name
    end
    return dir .. "/" .. name
end

---@param path string
---@param ancestor string
---@return boolean
function Asset.is_under(path, ancestor)
    return path == ancestor or string.sub(path, 1, #ancestor + 1) == ancestor .. "/"
end

---@param path string A path of the save directory
function Asset:init(path)
    assert(string.sub(path, 1, 1) ~= "/")
    self._path = path
end

function Asset:create()
    _create_intermediate_dirs(self._path)
    assert(love.filesystem.write(self._path, ""))
end

function Asset:create_directory()
    assert(love.filesystem.createDirectory(self._path))
end

---@param content string
function Asset:write(content)
    assert(love.filesystem.write(self._path, content))
end

---@return string
function Asset:read()
    return (love.filesystem.read(self._path))
end

---@return string|nil
function Asset:get_type()
    local info = love.filesystem.getInfo(self._path)
    return info and info.type
end

---@return number|nil
function Asset:get_size()
    return (love.filesystem.getInfo(self._path) or {}).size
end

---@return string|nil
function Asset:get_path()
    local info = love.filesystem.getInfo(self._path)
    return info and self._path
end

function Asset:remove()
    _remove_tree(self._path)
end

---@param other Asset
function Asset:move_to(other)
    assert(self:get_type(), "nothing to move")
    assert(not other:get_type(), "the destination exists")
    _create_intermediate_dirs(other._path)
    _copy_tree(self._path, other._path)
    _remove_tree(self._path)
end

return Asset

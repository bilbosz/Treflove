local Consts = require("app.consts")

---@class Asset
---@field private _path string
local Asset = class("Asset")

---@param path string
---@return void
local function _create_intermediate_dirs(path)
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

---@param virtual_path string
---@return string
function Asset.get_asset_path(virtual_path)
    return (app.is_server and Consts.ASSETS_SERVER_ROOT or Consts.ASSETS_CLIENT_ROOT) .. "/assets/" .. virtual_path
end

---@param virtual_path string
---@return string
function Asset.get_root_path(virtual_path)
    return (app.is_server and Consts.ASSETS_SERVER_ROOT or Consts.ASSETS_CLIENT_ROOT) .. "/" .. virtual_path
end

---@param path string
---@param is_on_root boolean
---@return void
function Asset:init(path, is_on_root)
    assert(string.sub(path, 1, 1) ~= "/")
    self._path = is_on_root and Asset.get_root_path(path) or Asset.get_asset_path(path)
end

---@return void
function Asset:create()
    _create_intermediate_dirs(self._path)
    assert(love.filesystem.write(self._path, ""))
end

---@param content string
---@return void
function Asset:write(content)
    assert(love.filesystem.write(self._path, content))
end

---@return string
function Asset:read()
    return love.filesystem.read(self._path)
end

---@return string|nil
function Asset:get_type()
    local info = love.filesystem.getInfo(self._path)
    return info and info.type
end

---@return number
function Asset:get_size()
    local info = love.filesystem.getInfo(self._path)
    return info and info.size
end

---@return string
function Asset:get_path()
    local info = love.filesystem.getInfo(self._path)
    return info and self._path
end

return Asset

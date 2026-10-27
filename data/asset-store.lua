local images = require("graphics.images")

local Asset = require("data.asset")

---@class AssetStore: Object
---@field private _root string
local AssetStore = class("AssetStore")

---@param directory string A directory of the save directory, a real path
---@param prefix string What the entries' paths start with, `""` at the top
---@param entries AssetEntry[] Output, in walk order
local function _list_tree(directory, prefix, entries)
    local items = love.filesystem.getDirectoryItems(directory)
    table.sort(items)
    for _, item in ipairs(items) do
        local real = directory .. "/" .. item
        local info = love.filesystem.getInfo(real)
        if info and (info.type == "file" or info.type == "directory") then
            table.insert(entries, {
                path = prefix .. item,
                type = info.type,
                size = info.size
            })
            if info.type == "directory" then
                _list_tree(real, prefix .. item .. "/", entries)
            end
        end
    end
end

---@param root string A directory of the save directory: a game's, `s/games/<id>` on the server, `c/games/<id>` on the client; the assets are under its `assets`
function AssetStore:init(root)
    assert_type(root, "string")
    self._root = root
end

---@return string
function AssetStore:get_root()
    return self._root
end

---@param virtual_path string Relative to the store's assets
---@return string The path in the save directory, whether the asset exists or not
function AssetStore:get_path(virtual_path)
    return self._root .. "/assets/" .. virtual_path
end

---@param virtual_path string Relative to the store's assets
---@return Asset
function AssetStore:asset(virtual_path)
    return Asset(self:get_path(virtual_path))
end

---@return AssetEntry[] Parents before their content, siblings by name
function AssetStore:list()
    ---@type AssetEntry[]
    local entries = {}
    local directory = self._root .. "/assets"
    if love.filesystem.getInfo(directory) then
        _list_tree(directory, "", entries)
    end
    return entries
end

---@param path string Relative to the store's assets
---@param content string Base64
---@return boolean ok
---@return string|nil err Why not, for the user: a bad path, or a folder's
function AssetStore:mount_file(path, content)
    local reason = Asset.check_path(path)
    if reason then
        return false, string.format("Cannot upload %q: %s", path, reason)
    end
    local file = self:asset(path)
    local existing = file:get_type()
    if existing == "directory" then
        return false, string.format("Cannot upload %q: it is a folder", path)
    end
    if not existing then
        file:create()
    end
    file:write(love.data.decode("string", "base64", content) --[[@as string]] )
    images.forget(self:get_path(path))
    return true
end

---@param path string Relative to the store's assets
---@return string|nil content Base64, `nil` when the store has no such file
function AssetStore:get_content(path)
    if Asset.check_path(path) then
        return nil
    end
    local file = self:asset(path)
    if file:get_type() ~= "file" then
        return nil
    end
    return love.data.encode("string", "base64", file:read(), file:get_size()) --[[@as string]]
end

---@param path string Relative to the store's assets
---@return boolean ok
---@return string|nil err Why not, for the user
function AssetStore:make_folder(path)
    local reason = Asset.check_path(path)
    if reason then
        return false, string.format("Cannot create %q: %s", path, reason)
    end
    local folder = self:asset(path)
    if folder:get_type() then
        return false, string.format("Cannot create %q: it exists already", path)
    end
    folder:create_directory()
    return true
end

---@param path string Relative to the store's assets
---@param new_path string Relative to the store's assets
---@return boolean ok
---@return string|nil err Why not, for the user
function AssetStore:move(path, new_path)
    local reason = Asset.check_path(path) or Asset.check_path(new_path)
    if reason then
        return false, string.format("Cannot rename %q to %q: %s", path, new_path, reason)
    end
    local source = self:asset(path)
    if not source:get_type() then
        return false, string.format("Cannot rename %q: there is no such asset", path)
    end
    if Asset.is_under(new_path, path) then
        return false, string.format("Cannot rename %q to %q: it would end up under itself", path, new_path)
    end
    local destination = self:asset(new_path)
    if destination:get_type() then
        return false, string.format("Cannot rename %q to %q: it exists already", path, new_path)
    end
    source:move_to(destination)
    return true
end

---@param path string Relative to the store's assets
---@return boolean ok
---@return string|nil err Why not, for the user
function AssetStore:remove(path)
    local reason = Asset.check_path(path)
    if reason then
        return false, string.format("Cannot delete %q: %s", path, reason)
    end
    local asset = self:asset(path)
    if not asset:get_type() then
        return false, string.format("Cannot delete %q: there is no such asset", path)
    end
    asset:remove()
    return true
end

return AssetStore

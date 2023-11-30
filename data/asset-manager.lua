local Asset = require("data.asset")
local DownloadAssetRp = require("data.download-asset-rp")
local DownloadMissingAssetsRp = require("data.download-missing-assets-rp")
local UploadAssetRp = require("data.upload-asset-rp")

---@class AssetManager
---@field private _download_asset_rp table<Session, DownloadAssetRp>
---@field private _download_missing_assets_rp table<Session, DownloadMissingAssetsRp>
---@field private _upload_asset_rp table<Session, UploadAssetRp>
local AssetManager = class("AssetManager")

---@param list string[]
---@return void
local function _filter_for_missing_assets(list)
    for i, v in ripairs(list) do
        if Asset(v):get_type() then
            table.remove(list, i)
        end
    end
end

---@generic T
---@param rp_list table<Session, T>
---@return T
local function _get_any_rp(rp_list)
    return select(2, next(rp_list))
end

---@param path string
---@return void
local function _remove_server_mount(path)
    local info = love.filesystem.getInfo(path)
    if not info then
        return
    end
    if info.type == "file" then
        love.filesystem.remove(path)
    elseif info.type == "directory" then
        local items = love.filesystem.getDirectoryItems(path)
        for _, v in ipairs(items) do
            _remove_server_mount(path .. "/" .. v)
        end
        love.filesystem.remove(path)
    else
        assert_unreachable()
    end
end

---@param src_path string
---@param dst_path string
---@return void
local function _mount_server_assets(src_path, dst_path)
    local src_info = love.filesystem.getInfo(src_path)
    if src_info.type == "file" then
        local data = love.filesystem.read(src_path)
        love.filesystem.write(dst_path, data)
    elseif src_info.type == "directory" then
        love.filesystem.createDirectory(dst_path)
        local items = love.filesystem.getDirectoryItems(src_path)
        for _, v in ipairs(items) do
            _mount_server_assets(src_path .. "/" .. v, dst_path .. "/" .. v)
        end
    else
        assert_unreachable()
    end
end

---@return void
function AssetManager:init()
    -- remote procedures by session
    if app.is_server then
        _remove_server_mount("s")
        _mount_server_assets("server", "s")
    end
    self._upload_asset_rp = {}
    self._download_asset_rp = {}
    self._download_missing_assets_rp = {}
end

---@param mount_point string
---@param content string
---@return void
function AssetManager:mount_file(mount_point, content)
    local file = Asset(mount_point)
    if not file:get_type() then
        file:create()
    end
    file:write(love.data.decode("string", "base64", content))
end

---@param path string
---@return string
function AssetManager:get_content(path)
    local file = Asset(path)
    if file:get_type() ~= "file" then
        return nil
    end
    return love.data.encode("string", "base64", file:read(), file:get_size())
end

---@param path string
---@param data string
---@param data_size number
---@return void
function AssetManager:upload_asset(path, data, data_size)
    assert(app.is_client)

    local rp = _get_any_rp(self._upload_asset_rp)
    rp:send_request({
        path = path,
        content = love.data.encode("string", "base64", data, data_size)
    })
end

---@param path string
---@return void
function AssetManager:download_asset(path)
    assert(app.is_client)

    local rp = _get_any_rp(self._download_asset_rp)
    rp:send_request({
        path = path
    })
end

---TODO type to be resolved
---@param list string[]
---@param cb ToDo
---@return void
function AssetManager:download_missing_assets(list, cb)
    _filter_for_missing_assets(list)

    local rp = _get_any_rp(self._download_missing_assets_rp)
    rp:send_request({
        list = list
    }, cb)
end

---@param session Session
---@return void
function AssetManager:register_session(session)
    local connection = session:get_connection()
    self._upload_asset_rp[session] = UploadAssetRp(connection)
    self._download_asset_rp[session] = DownloadAssetRp(connection)
    self._download_missing_assets_rp[session] = DownloadMissingAssetsRp(connection)
end

---@param session Session
---@return void
function AssetManager:unregister_session(session)
    self._upload_asset_rp[session]:release()
    self._upload_asset_rp[session] = nil

    self._download_asset_rp[session]:release()
    self._download_asset_rp[session] = nil

    self._download_missing_assets_rp[session]:release()
    self._download_missing_assets_rp[session] = nil
end

return AssetManager

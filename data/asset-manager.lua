local images = require("graphics.images")

local Asset = require("data.asset")
local CreateAssetFolderRp = require("data.create-asset-folder-rp")
local DeleteAssetRp = require("data.delete-asset-rp")
local DownloadAssetRp = require("data.download-asset-rp")
local DownloadMissingAssetsRp = require("data.download-missing-assets-rp")
local ListAssetsRp = require("data.list-assets-rp")
local RenameAssetRp = require("data.rename-asset-rp")
local UploadAssetRp = require("data.upload-asset-rp")
local lifetime = require("lifetime")

---@class AssetManager: Object
---@field private _download_asset_rp table<Session, DownloadAssetRp>
---@field private _download_missing_assets_rp table<Session, DownloadMissingAssetsRp>
---@field private _upload_asset_rp table<Session, UploadAssetRp>
---@field private _list_assets_rp table<Session, ListAssetsRp>
---@field private _create_asset_folder_rp table<Session, CreateAssetFolderRp>
---@field private _rename_asset_rp table<Session, RenameAssetRp>
---@field private _delete_asset_rp table<Session, DeleteAssetRp>
local AssetManager = class("AssetManager")

---@param list string[]
local function _filter_for_missing_assets(list)
    for i, v in ripairs(list) do
        if Asset(v, false):get_type() then
            table.remove(list, i)
        end
    end
end

---@generic T
---@param rp_list table<Session, T>
---@return T
local function _get_client_rp(rp_list)
    assert(app.is_client)
    local rp = rp_list[assert(app.session)]
    assert(rp, "no procedure registered for the client's session")
    return rp
end

---@param path string
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

function AssetManager:init()
    if app.is_server then
        _remove_server_mount("s")
        _mount_server_assets("server", "s")
    end
    self._upload_asset_rp = {}
    self._download_asset_rp = {}
    self._download_missing_assets_rp = {}
    self._list_assets_rp = {}
    self._create_asset_folder_rp = {}
    self._rename_asset_rp = {}
    self._delete_asset_rp = {}
end

---@param mount_point string
---@param content string Base64
---@return boolean ok
---@return string|nil err Why not, for the user: a bad path, or a folder's
function AssetManager:mount_file(mount_point, content)
    local reason = Asset.check_path(mount_point)
    if reason then
        return false, string.format("Cannot upload %q: %s", mount_point, reason)
    end
    local file = Asset(mount_point, false)
    local existing = file:get_type()
    if existing == "directory" then
        return false, string.format("Cannot upload %q: it is a folder", mount_point)
    end
    if not existing then
        file:create()
    end
    file:write(love.data.decode("string", "base64", content) --[[@as string]] )
    images.forget(Asset.get_asset_path(mount_point))
    return true
end

---@param path string
---@return string|nil
function AssetManager:get_content(path)
    local file = Asset(path, false)
    if file:get_type() ~= "file" then
        return nil
    end
    return love.data.encode("string", "base64", file:read(), file:get_size()) --[[@as string]]
end

---@param path string
---@return boolean ok
---@return string|nil err Why not, for the user
function AssetManager:make_folder(path)
    local reason = Asset.check_path(path)
    if reason then
        return false, string.format("Cannot create %q: %s", path, reason)
    end
    if Asset(path, false):get_type() then
        return false, string.format("Cannot create %q: it exists already", path)
    end
    Asset(path, false):create_directory()
    return true
end

---@param path string
---@param new_path string
---@return boolean ok
---@return string|nil err Why not, for the user
function AssetManager:move(path, new_path)
    local reason = Asset.check_path(path) or Asset.check_path(new_path)
    if reason then
        return false, string.format("Cannot rename %q to %q: %s", path, new_path, reason)
    end
    local source = Asset(path, false)
    if not source:get_type() then
        return false, string.format("Cannot rename %q: there is no such asset", path)
    end
    if Asset.is_under(new_path, path) then
        return false, string.format("Cannot rename %q to %q: it would end up under itself", path, new_path)
    end
    local destination = Asset(new_path, false)
    if destination:get_type() then
        return false, string.format("Cannot rename %q to %q: it exists already", path, new_path)
    end
    source:move_to(destination)
    return true
end

---@param path string
---@return boolean ok
---@return string|nil err Why not, for the user
function AssetManager:remove(path)
    local reason = Asset.check_path(path)
    if reason then
        return false, string.format("Cannot delete %q: %s", path, reason)
    end
    local asset = Asset(path, false)
    if not asset:get_type() then
        return false, string.format("Cannot delete %q: there is no such asset", path)
    end
    asset:remove()
    return true
end

---@param path string
---@param data string|love.Data The file's bytes
---@param cb RemoteProcedureCallback|nil Called with the `UploadAssetResponse`
function AssetManager:upload_asset(path, data, cb)
    local rp = _get_client_rp(self._upload_asset_rp)
    rp:send_request({
        path = path,
        content = love.data.encode("string", "base64", data)
    }, cb)
end

---@param path string
---@param cb RemoteProcedureCallback|nil Called with the `DownloadAssetResponse`, the asset mounted when the server had it
function AssetManager:download_asset(path, cb)
    local rp = _get_client_rp(self._download_asset_rp)
    rp:send_request({
        path = path
    }, cb)
end

---@param cb RemoteProcedureCallback Called with the `ListAssetsResponse`
function AssetManager:list_assets(cb)
    local rp = _get_client_rp(self._list_assets_rp)
    rp:send_request({}, cb)
end

---@param path string
---@param cb RemoteProcedureCallback|nil Called with the `CreateAssetFolderResponse`
function AssetManager:create_folder(path, cb)
    local rp = _get_client_rp(self._create_asset_folder_rp)
    rp:send_request({
        path = path
    }, cb)
end

---@param path string
---@param new_path string
---@param cb RemoteProcedureCallback|nil Called with the `RenameAssetResponse`
function AssetManager:rename_asset(path, new_path, cb)
    local rp = _get_client_rp(self._rename_asset_rp)
    rp:send_request({
        path = path,
        new_path = new_path
    }, cb)
end

---@param path string
---@param cb RemoteProcedureCallback|nil Called with the `DeleteAssetResponse`
function AssetManager:delete_asset(path, cb)
    local rp = _get_client_rp(self._delete_asset_rp)
    rp:send_request({
        path = path
    }, cb)
end

---@param list string[]
---@param cb fun()
function AssetManager:download_missing_assets(list, cb)
    _filter_for_missing_assets(list)

    local rp = _get_client_rp(self._download_missing_assets_rp)
    rp:send_request({
        list = list
    }, cb)
end

---@param session Session
function AssetManager:register_session(session)
    local connection = session:get_connection()
    self._upload_asset_rp[session] = UploadAssetRp(session):attach_lifetime(session)
    self._download_asset_rp[session] = DownloadAssetRp(connection):attach_lifetime(session)
    self._download_missing_assets_rp[session] = DownloadMissingAssetsRp(connection):attach_lifetime(session)
    self._list_assets_rp[session] = ListAssetsRp(session):attach_lifetime(session)
    self._create_asset_folder_rp[session] = CreateAssetFolderRp(session):attach_lifetime(session)
    self._rename_asset_rp[session] = RenameAssetRp(session):attach_lifetime(session)
    self._delete_asset_rp[session] = DeleteAssetRp(session):attach_lifetime(session)
    lifetime.hook(function()
        self._upload_asset_rp[session] = nil
        self._download_asset_rp[session] = nil
        self._download_missing_assets_rp[session] = nil
        self._list_assets_rp[session] = nil
        self._create_asset_folder_rp[session] = nil
        self._rename_asset_rp[session] = nil
        self._delete_asset_rp[session] = nil
    end, session)
end

return AssetManager

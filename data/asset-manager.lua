local CreateAssetFolderRp = require("data.create-asset-folder-rp")
local DeleteAssetRp = require("data.delete-asset-rp")
local DownloadAssetRp = require("data.download-asset-rp")
local DownloadMissingAssetsRp = require("data.download-missing-assets-rp")
local ListAssetsRp = require("data.list-assets-rp")
local RenameAssetRp = require("data.rename-asset-rp")
local UploadAssetRp = require("data.upload-asset-rp")
local lifetime = require("lifetime")

---@class AssetManager: Object
---@field private _store AssetStore|nil The client's: the copies of the joined game's assets, from the game data on
---@field private _download_asset_rp table<Session, DownloadAssetRp>
---@field private _download_missing_assets_rp table<Session, DownloadMissingAssetsRp>
---@field private _upload_asset_rp table<Session, UploadAssetRp>
---@field private _list_assets_rp table<Session, ListAssetsRp>
---@field private _create_asset_folder_rp table<Session, CreateAssetFolderRp>
---@field private _rename_asset_rp table<Session, RenameAssetRp>
---@field private _delete_asset_rp table<Session, DeleteAssetRp>
local AssetManager = class("AssetManager")

---@param store AssetStore
---@param list string[]
local function _filter_for_missing_assets(store, list)
    for i, v in ripairs(list) do
        if store:asset(v):get_type() then
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

function AssetManager:init()
    self._store = nil
    self._upload_asset_rp = {}
    self._download_asset_rp = {}
    self._download_missing_assets_rp = {}
    self._list_assets_rp = {}
    self._create_asset_folder_rp = {}
    self._rename_asset_rp = {}
    self._delete_asset_rp = {}
end

---@param store AssetStore|nil The joined game's copies, `nil` when there is no game
function AssetManager:set_store(store)
    assert(app.is_client)
    self._store = store
end

---@return AssetStore|nil store The client's, from the game data on; `nil` before, and on the server, where every session's game has its own
function AssetManager:get_store()
    return self._store
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
    _filter_for_missing_assets(assert(self._store, "assets need a joined game"), list)

    local rp = _get_client_rp(self._download_missing_assets_rp)
    rp:send_request({
        list = list
    }, cb)
end

---@param session Session
function AssetManager:register_session(session)
    self._upload_asset_rp[session] = UploadAssetRp(session):attach_lifetime(session)
    self._download_asset_rp[session] = DownloadAssetRp(session):attach_lifetime(session)
    self._download_missing_assets_rp[session] = DownloadMissingAssetsRp(session):attach_lifetime(session)
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

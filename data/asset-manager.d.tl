-- data/asset-manager.lua (still Lua): assets on disk and the per-session
-- remote procedures that move them between client and server.
global interface AssetManager is Object
    -- The procedures by session. lifetime: each is anchored to its session
    -- (`@ session`, docs/lifetime.md) and the tables become weak in keys
    -- and values (lua-lifetime trial, "data/asset-manager.lt").
    _download_asset_rp: {Session: DownloadAssetRp}
    _download_missing_assets_rp: {Session: DownloadMissingAssetsRp}
    _upload_asset_rp: {Session: UploadAssetRp}
    mount_file: function(self, mount_point: string, content: string)
    get_content: function(self, path: string): string -- base64; nil if no such file
    upload_asset: function(self, path: string, data: string)
    download_asset: function(self, path: string)
    download_missing_assets: function(self, list: {string}, cb: function())
    register_session: function(self, session: Session)
    -- lifetime: goes away when this module is converted (the procedures die
    -- with the session they are anchored to); Phase 0's Lua still calls it.
    unregister_session: function(self, session: Session)
end

-- data/asset.tlt: a file under the assets root of the running
-- side (server or client), on LÖVE's filesystem.
global interface Asset is Object
    _path: string -- the real path on LÖVE's filesystem
    -- Static (called on the class table, `Asset.get_asset_path(p)`).
    get_asset_path: function(virtual_path: string): string
    get_root_path: function(virtual_path: string): string
    create: function(self)
    write: function(self, content: string)
    read: function(self): string
    get_type: function(self): love.FileType -- nil when the file does not exist
    get_size: function(self): number -- nil when the file does not exist
    get_path: function(self): string -- nil when the file does not exist
end

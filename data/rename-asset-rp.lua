local Asset = require("data.asset")
local RemoteProcedure = require("networking.remote-procedure")
local asset_usage = require("data.asset-usage")
local permissions = require("game.permissions")

---@class RenameAssetRequest: RequestBody
---@field public path string
---@field public new_path string

---@class RenameAssetResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user
---@field public path string
---@field public new_path string

---@class RenameAssetRp: RemoteProcedure
---@field private _session Session
local RenameAssetRp = class("RenameAssetRp", RemoteProcedure)

---@param session Session
function RenameAssetRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request RenameAssetRequest
---@return RenameAssetResponse
function RenameAssetRp:send_response(request)
    assert(app.is_server)
    local path, new_path = request.path, request.new_path
    if not self._session:is_allowed(permissions.Action.WRITE, permissions.Kind.ASSETS) then
        return {
            success = false,
            error = "Not allowed to change assets",
            path = path,
            new_path = new_path
        }
    end
    local ok, err = app.asset_manager:move(path, new_path)
    if ok then
        asset_usage.rename(assert(app.data), path, new_path)
    end
    return {
        success = ok,
        error = err,
        path = path,
        new_path = new_path
    }
end

---@param response RenameAssetResponse
function RenameAssetRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot rename the asset")
        return
    end
    local source, destination = Asset(response.path, false), Asset(response.new_path, false)
    if destination:get_type() then
        destination:remove()
    end
    if source:get_type() then
        source:move_to(destination)
    end
end

return RenameAssetRp

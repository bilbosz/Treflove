local RemoteProcedure = require("networking.remote-procedure")
local asset_usage = require("data.asset-usage")
local permissions = require("game.permissions")

---@class DeleteAssetRequest: RequestBody
---@field public path string

---@class DeleteAssetResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user
---@field public path string

---@class DeleteAssetRp: RemoteProcedure
---@field private _session Session
local DeleteAssetRp = class("DeleteAssetRp", RemoteProcedure)

---@param session Session
function DeleteAssetRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request DeleteAssetRequest
---@return DeleteAssetResponse
function DeleteAssetRp:send_response(request)
    assert(app.is_server)
    local path = request.path
    if not self._session:is_allowed(permissions.Action.WRITE, permissions.Kind.ASSETS) then
        return {
            success = false,
            error = "Not allowed to change assets",
            path = path
        }
    end
    local game = self._session:get_game()
    local used_by = asset_usage.find(game:get_data(), path)
    if #used_by > 0 then
        ---@type string[]
        local names = {}
        for _, use in ipairs(used_by) do
            table.insert(names, asset_usage.describe(use))
        end
        return {
            success = false,
            error = string.format("Cannot delete %q: used by %s", path, table.concat(names, ", ")),
            path = path
        }
    end
    local ok, err = game:get_store():remove(path)
    return {
        success = ok,
        error = err,
        path = path
    }
end

---@param response DeleteAssetResponse
function DeleteAssetRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot delete the asset")
        return
    end
    local copy = assert(app.asset_manager:get_store()):asset(response.path)
    if copy:get_type() then
        copy:remove()
    end
end

return DeleteAssetRp

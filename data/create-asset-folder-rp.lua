local RemoteProcedure = require("networking.remote-procedure")
local permissions = require("game.permissions")

---@class CreateAssetFolderRequest: RequestBody
---@field public path string

---@class CreateAssetFolderResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user
---@field public path string

---@class CreateAssetFolderRp: RemoteProcedure
---@field private _session Session
local CreateAssetFolderRp = class("CreateAssetFolderRp", RemoteProcedure)

---@param session Session
function CreateAssetFolderRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@param request CreateAssetFolderRequest
---@return CreateAssetFolderResponse
function CreateAssetFolderRp:send_response(request)
    assert(app.is_server)
    if not self._session:is_allowed(permissions.Action.WRITE, permissions.Kind.ASSETS) then
        return {
            success = false,
            error = "Not allowed to change assets",
            path = request.path
        }
    end
    local ok, err = self._session:get_game():get_store():make_folder(request.path)
    return {
        success = ok,
        error = err,
        path = request.path
    }
end

---@param response CreateAssetFolderResponse
function CreateAssetFolderRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot create the folder")
    end
end

return CreateAssetFolderRp

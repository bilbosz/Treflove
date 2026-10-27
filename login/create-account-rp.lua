local RemoteProcedure = require("networking.remote-procedure")

---@class CreateAccountRequest: RequestBody
---@field public login string
---@field public name string
---@field public auth string The client hash, as `LoginRequest.auth`

---@class CreateAccountResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user

---@class CreateAccountRp: RemoteProcedure
local CreateAccountRp = class("CreateAccountRp", RemoteProcedure)

---@param connection Connection
function CreateAccountRp:init(connection)
    RemoteProcedure.init(self, connection)
end

---@param request CreateAccountRequest
---@return CreateAccountResponse
function CreateAccountRp:send_response(request)
    assert(app.is_server)
    local ok, err = assert(app.accounts):create(request.login, request.name, request.auth)
    return {
        success = ok,
        error = err
    }
end

---@param response CreateAccountResponse
function CreateAccountRp:receive_response(response)
    assert(app.is_client)
    if response.success then
        app.notification_manager:notify("Account created", 3)
    else
        app.notification_manager:notify(response.error or "Cannot create the account")
    end
end

return CreateAccountRp

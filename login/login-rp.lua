local RemoteProcedure = require("networking.remote-procedure")

---@class LoginRequest: RequestBody
---@field public auth string

---@class LoginResponse: ResponseBody
---@field public user string|nil `nil` when the credentials match no user

---@alias LoginCallback fun(user: string) Called with the user name once logged in

---@class LoginRp: RemoteProcedure
---@field on_login LoginCallback
local LoginRp = class("LoginRp", RemoteProcedure)

---@param connection Connection
---@param on_login LoginCallback
function LoginRp:init(connection, on_login)
    RemoteProcedure.init(self, connection)
    self.on_login = on_login
end

---@param request LoginRequest
---@return LoginResponse
function LoginRp:send_response(request)
    assert(app.is_server)
    local user = assert(app.accounts):find_by_auth(request.auth)
    if user then
        self.on_login(user)
    end
    return {
        user = user
    }
end

---@param response LoginResponse
function LoginRp:receive_response(response)
    assert(app.is_client)
    if response.user then
        app.notification_manager:notify(string.format("Successfully logged in as %s", response.user), 3)
        self.on_login(response.user)
    else
        app.notification_manager:notify("Wrong login or password")
    end
end

return LoginRp

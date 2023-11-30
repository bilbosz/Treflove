local RemoteProcedure = require("networking.remote-procedure")
local Utils = require("utils.utils")

---@class LoginRp: RemoteProcedure
local LoginRp = class("LoginRp", RemoteProcedure)

local function _get_server_auth(userName, clientAuth)
    return Utils.hash(userName .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. clientAuth)
end

local function FindUserByClientAuth(clientAuth)
    for userName, userData in pairs(app.data.players) do
        local serverAuth = _get_server_auth(userName, clientAuth)
        if serverAuth == userData.auth then
            return userName
        end
    end
end

function LoginRp:init(connection, onLogin)
    RemoteProcedure.init(self, connection)
    self.onLogin = onLogin
end

function LoginRp:send_response(request)
    assert(app.is_server)
    local user = FindUserByClientAuth(request.auth)
    if user then
        self.onLogin(user)
    end
    return {
        user = user
    }
end

function LoginRp:receive_response(response)
    assert(app.is_client)
    if response.user then
        app.notification_manager:notify(string.format("Successfully logged in as %s", response.user), 3)
        self.onLogin(response.user)
    else
        app.notification_manager:notify("Wrong login or password")
    end
end

return LoginRp

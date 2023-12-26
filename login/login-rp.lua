local RemoteProcedure = require("networking.remote-procedure")
local Utils = require("utils.utils")

---@class LoginRp: RemoteProcedure
local LoginRp = class("LoginRp", RemoteProcedure)

local function _get_server_auth(user_name, client_auth)
    return Utils.hash(user_name .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. client_auth)
end

local function _find_user_by_client_auth(client_auth)
    for user_name, user_data in pairs(app.data.players) do
        local server_auth = _get_server_auth(user_name, client_auth)
        if server_auth == user_data.auth then
            return user_name
        end
    end
end

function LoginRp:init(connection, on_login)
    RemoteProcedure.init(self, connection)
    self.on_login = on_login
end

function LoginRp:send_response(request)
    assert(app.is_server)
    local user = _find_user_by_client_auth(request.auth)
    if user then
        self.on_login(user)
    end
    return {
        user = user
    }
end

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

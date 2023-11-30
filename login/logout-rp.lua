local RemoteProcedure = require("networking.remote-procedure")

---@class LogoutRp: RemoteProcedure
local LogoutRp = class("LogoutRp", RemoteProcedure)

function LogoutRp:init(connection, onLogout)
    RemoteProcedure.init(self, connection)
    self.onLogout = onLogout
end

function LogoutRp:send_response()
    assert(app.is_server)
    self.onLogout()
    return {}
end

function LogoutRp:receive_response()
    assert(app.is_client)
    self.onLogout()
end

return LogoutRp

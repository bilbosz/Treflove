local RemoteProcedure = require("networking.remote-procedure")

---@class LogoutRp: RemoteProcedure
---@field on_logout fun()
local LogoutRp = class("LogoutRp", RemoteProcedure)

---@param connection Connection
---@param on_logout fun()
function LogoutRp:init(connection, on_logout)
    RemoteProcedure.init(self, connection)
    self.on_logout = on_logout
end

---@return table
function LogoutRp:send_response()
    assert(app.is_server)
    self.on_logout()
    return {}
end

function LogoutRp:receive_response()
    assert(app.is_client)
    self.on_logout()
end

return LogoutRp

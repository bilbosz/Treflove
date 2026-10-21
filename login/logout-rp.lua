local RemoteProcedure = require("networking.remote-procedure")

---@alias LogoutCallback fun()

---@class LogoutRp: RemoteProcedure
---@field on_logout LogoutCallback
local LogoutRp = class("LogoutRp", RemoteProcedure)

---@param connection Connection
---@param on_logout LogoutCallback
function LogoutRp:init(connection, on_logout)
    RemoteProcedure.init(self, connection)
    self.on_logout = on_logout
end

---@return ResponseBody
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

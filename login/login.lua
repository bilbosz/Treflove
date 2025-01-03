local LoginRp = require("login.login-rp")
local LogoutRp = require("login.logout-rp")
local Utils = require("utils.utils")

---@class Login
---@field private _connection Connection
---@field private _login_rp LoginRp
---@field private _logout_rp LogoutRp
local Login = class("Login")

---@param user_name string
---@param password string
---@return string
local function _get_client_auth(user_name, password)
    local auth = Utils.hash(user_name .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. password)
    return auth
end

---@param session Session
---@param on_login fun(user:string):void
---@param on_logout fun():void
function Login:init(session, on_login, on_logout)
    self._connection = session:get_connection()
    self._login_rp = LoginRp(self._connection, on_login)
    self._logout_rp = LogoutRp(self._connection, on_logout)
end

---@param user string
---@param password string
function Login:login(user, password)
    assert(app.is_client)
    self._login_rp:send_request({
        auth = _get_client_auth(user, password)
    })
end

function Login:logout()
    assert(app.is_client)
    self._logout_rp:send_request({})
end

function Login:release()
    self._login_rp:release()
    self._logout_rp:release()
end

return Login

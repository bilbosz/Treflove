local LoginRp = require("login.login-rp")
local LogoutRp = require("login.logout-rp")
local Utils = require("utils.utils")
local lifetime = require("lifetime")

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
---@param on_login fun(user:string)
---@param on_logout fun()
function Login:init(session, on_login, on_logout)
    self._connection = session:get_connection()
    -- lua-lifetime: the procedures die with the login; Login:release is gone.
    self._login_rp = lifetime.attach(LoginRp(self._connection, on_login), self)
    self._logout_rp = lifetime.attach(LogoutRp(self._connection, on_logout), self)
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

return Login

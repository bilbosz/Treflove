local CreateAccountRp = require("login.create-account-rp")
local LoginRp = require("login.login-rp")
local LogoutRp = require("login.logout-rp")
local Utils = require("utils.utils")

---@class Login: Object
---@field private _connection Connection
---@field private _login_rp LoginRp
---@field private _logout_rp LogoutRp
---@field private _create_account_rp CreateAccountRp
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
    self._login_rp = LoginRp(self._connection, on_login):attach_lifetime(self)
    self._logout_rp = LogoutRp(self._connection, on_logout):attach_lifetime(self)
    self._create_account_rp = CreateAccountRp(self._connection):attach_lifetime(self)
end

---@param user string
---@param password string
function Login:login(user, password)
    assert(app.is_client)
    self._login_rp:send_request({
        auth = _get_client_auth(user, password)
    })
end

---@param user string
---@param name string
---@param password string
---@param cb fun(response: CreateAccountResponse) Called once the server answered
function Login:sign_up(user, name, password, cb)
    assert(app.is_client)
    self._create_account_rp:send_request({
        login = user,
        name = name,
        auth = _get_client_auth(user, password)
    }, function(response)
        cb(response --[[@as CreateAccountResponse]] )
    end)
end

function Login:logout()
    assert(app.is_client)
    self._logout_rp:send_request({})
end

return Login

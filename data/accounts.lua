local Consts = require("app.consts")
local Utils = require("utils.utils")

---@class AccountData One account, as `s/accounts.lua` holds it by login
---@field name string Display name
---@field auth string The server-side hash of the client hash of the login and the password

---@class Accounts: Object
---@field private _file Asset
---@field private _accounts table<string, AccountData> By login
local Accounts = class("Accounts")

---@param login string
---@param client_auth string
---@return string
local function _get_server_auth(login, client_auth)
    return Utils.hash(login .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. client_auth)
end

---@param text string
---@return string
local function _trim(text)
    return (string.match(text, "^%s*(.-)%s*$"))
end

---@param login string
---@return string|nil reason Why the login cannot be an account's, for the user; `nil` when it can
function Accounts.check_login(login)
    if type(login) ~= "string" or login == "" then
        return "A login cannot be empty"
    end
    if #login > Consts.ACCOUNT_LOGIN_MAX_LENGTH then
        return string.format("A login can have at most %d characters", Consts.ACCOUNT_LOGIN_MAX_LENGTH)
    end
    if string.find(login, "[^%w_%.%-]") then
        return "A login can have only letters, digits and the characters _ . -"
    end
    return nil
end

---@param name string
---@return string|nil reason Why the name cannot be an account's, for the user; `nil` when it can
function Accounts.check_name(name)
    if type(name) ~= "string" or _trim(name) == "" then
        return "A name cannot be empty"
    end
    if #_trim(name) > Consts.ACCOUNT_NAME_MAX_LENGTH then
        return string.format("A name can have at most %d characters", Consts.ACCOUNT_NAME_MAX_LENGTH)
    end
    return nil
end

---@param password string
---@return string|nil reason Why the password cannot be an account's, for the user; `nil` when it can
function Accounts.check_password(password)
    if type(password) ~= "string" or password == "" then
        return "A password cannot be empty"
    end
    return nil
end

---@param file Asset The accounts file, read now: no accounts when it does not exist
function Accounts:init(file)
    self._file = file
    self._accounts = {}
    if file:get_type() == "file" then
        self._accounts = assert(table.from_string(file:read()), "the accounts file does not load") --[[@as table<string, AccountData>]]
    end
end

---@param login string
---@return AccountData|nil
function Accounts:get(login)
    return self._accounts[login]
end

---@param client_auth string What a client's `Login` sends
---@return string|nil login The account's whose auth `client_auth` matches
function Accounts:find_by_auth(client_auth)
    if type(client_auth) ~= "string" then
        return nil
    end
    for login, account in pairs(self._accounts) do
        if _get_server_auth(login, client_auth) == account.auth then
            return login
        end
    end
    return nil
end

---@param login string
---@param name string Trimmed when stored
---@param client_auth string What the client's `Login` would send for the login and the password
---@return boolean ok
---@return string|nil err Why not, for the user
function Accounts:create(login, name, client_auth)
    local reason = Accounts.check_login(login) or Accounts.check_name(name)
    if reason then
        return false, reason
    end
    if type(client_auth) ~= "string" or client_auth == "" then
        return false, "An account needs a password"
    end
    if self._accounts[login] then
        return false, string.format("The login %q is taken already", login)
    end
    self._accounts[login] = {
        name = _trim(name),
        auth = _get_server_auth(login, client_auth)
    }
    self:_save()
    return true
end

---@private
function Accounts:_save()
    if not self._file:get_type() then
        self._file:create()
    end
    self._file:write(table.to_string(self._accounts))
end

return Accounts

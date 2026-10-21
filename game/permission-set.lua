local permissions = require("game.permissions")

---@alias PermissionSet.Entry {owners: any} An entry of a `GameData` collection, as the `@owned` selector reads it

---@class PermissionSet: Object The grants of one login, parsed
---@field private _login string
---@field private _grants string[]
---@field private _parsed Grant[]
local PermissionSet = class("PermissionSet")

---@param login string
---@param grants string[]
function PermissionSet:init(login, grants)
    assert_type(login, "string")
    self._login = login
    self._grants = table.copy(grants)
    self._parsed = {}
    for _, text in ipairs(grants) do
        table.insert(self._parsed, permissions.parse(text))
    end
end

---@return string
function PermissionSet:get_login()
    return self._login
end

---@return string[]
function PermissionSet:get_grants()
    return table.copy(self._grants)
end

---@param login string
---@param kind string
---@param key string
---@return boolean
local function _is_owned(login, kind, key)
    ---@type table<string, table<string, PermissionSet.Entry|nil>|nil>|nil
    local collections = app.data
    local collection = collections and collections[kind]
    local entry = type(collection) == "table" and collection[key]
    local owners = type(entry) == "table" and entry.owners
    return type(owners) == "table" and table.find_array_idx(owners, login) ~= nil
end

---@param login string
---@param grant Grant
---@param kind string|nil
---@param key string|nil
---@return boolean
local function _covers(login, grant, kind, key)
    if not grant.kind then
        return true
    end
    if not kind or grant.kind ~= kind then
        return false
    end
    if not grant.key then
        return true
    end
    if not key then
        return false
    end
    if grant.key == permissions.OWNED then
        return _is_owned(login, kind, key)
    end
    return grant.key == key
end

---@param action permissions.Action
---@param kind string|nil `nil` asks about everything
---@param key string|nil `nil` asks about the whole kind
---@return boolean
function PermissionSet:allows(action, kind, key)
    assert(kind or not key, "a key needs a kind")
    for _, grant in ipairs(self._parsed) do
        if grant.action == action and _covers(self._login, grant, kind, key) then
            return true
        end
    end
    return false
end

return PermissionSet

local permissions = require("game.permissions")

---@alias PermissionSet.Entry {owners: any} An entry of a `GameData` collection, as the `@owned` selector reads it

---@class PermissionSet: Object The grants of one login, parsed
---@field private _login string
---@field private _grants string[]
---@field private _parsed Grant[]
---@field private _data GameData What the `@owned` selector reads, as it is when asked
local PermissionSet = class("PermissionSet")

---@param grants string[]
---@return Grant[]
local function _parse_all(grants)
    ---@type Grant[]
    local parsed = {}
    for _, text in ipairs(grants) do
        table.insert(parsed, permissions.parse(text))
    end
    return parsed
end

---@param login string
---@param grants string[]
---@param data GameData The game the grants are on: the server's own, the client's `app.data`
function PermissionSet:init(login, grants, data)
    assert_type(login, "string")
    self._login = login
    self._data = data
    self._grants = table.copy(grants)
    self._parsed = _parse_all(grants)
end

---@return string
function PermissionSet:get_login()
    return self._login
end

---@return string[]
function PermissionSet:get_grants()
    return table.copy(self._grants)
end

---@param kind permissions.Kind
---@param key string
---@param new_key string
function PermissionSet:rename_key(kind, key, new_key)
    self._grants = permissions.rename_key(self._grants, kind, key, new_key)
    self._parsed = _parse_all(self._grants)
end

---@param kind permissions.Kind
---@param key string
function PermissionSet:remove_key(kind, key)
    self._grants = permissions.remove_key(self._grants, kind, key)
    self._parsed = _parse_all(self._grants)
end

---@param data GameData
---@param login string
---@param kind permissions.Kind
---@param key string
---@return boolean
local function _is_owned(data, login, kind, key)
    ---@type table<string, table<string, PermissionSet.Entry|nil>|nil>
    local collections = data
    local collection = collections[kind]
    local entry = type(collection) == "table" and collection[key]
    local owners = type(entry) == "table" and entry.owners
    return type(owners) == "table" and table.find_array_idx(owners, login) ~= nil
end

---@param data GameData
---@param login string
---@param grant Grant
---@param kind permissions.Kind|nil
---@param key string|nil
---@return boolean
local function _covers(data, login, grant, kind, key)
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
        return _is_owned(data, login, kind, key)
    end
    return grant.key == key
end

---@param action permissions.Action
---@param kind permissions.Kind|nil `nil` asks about everything
---@param key string|nil `nil` asks about the whole kind
---@return boolean
function PermissionSet:allows(action, kind, key)
    assert(kind or not key, "a key needs a kind")
    for _, grant in ipairs(self._parsed) do
        if grant.action == action and _covers(self._data, self._login, grant, kind, key) then
            return true
        end
    end
    return false
end

return PermissionSet

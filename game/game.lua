local Asset = require("data.asset")
local AssetStore = require("data.asset-store")
local PermissionSet = require("game.permission-set")
local lifetime = require("lifetime")
local permissions = require("game.permissions")

---@class Game: Object
---@field private _id string
---@field private _file Asset
---@field private _data GameData
---@field private _store AssetStore
---@field private _sessions table<Session, boolean> The sessions in the game, weak keys: a dead session drops out
local Game = class("Game")

---@param id string The game's directory name
---@param root string The game's directory, `s/games/<id>`: its `save.lua` is read now
function Game:init(id, root)
    assert_type(id, "string")
    self._id = id
    self._file = Asset(root .. "/save.lua")
    self._data = assert(table.from_string(self._file:read()), "the save of the game " .. id .. " does not load") --[[@as GameData]]
    self._store = AssetStore(root)
    self._sessions = setmetatable({}, {
        __mode = "k"
    })
end

---@return string
function Game:get_id()
    return self._id
end

---@return string
function Game:get_name()
    return self._data.name
end

---@return GameData The server's own, changed in place
function Game:get_data()
    return self._data
end

---@return AssetStore
function Game:get_store()
    return self._store
end

function Game:save()
    self._file:write(table.to_string(self._data))
end

---@param login string
---@param group string A key of the game's groups
function Game:add_player(login, group)
    if self._data.players[login] then
        return
    end
    self._data.players[login] = {
        group = group
    }
    self:save()
end

---@param login string
---@param action permissions.Action
---@param kind permissions.Kind|nil
---@param key string|nil
---@return boolean Whether the login is a player of the game whose grants in it, resolved from the data now, allow it
function Game:allows(login, action, kind, key)
    if not self._data.players[login] then
        return false
    end
    local set = PermissionSet(login, permissions.resolve(self._data, login), self._data)
    return set:allows(action, kind, key)
end

---@param session Session
function Game:add_session(session)
    self._sessions[session] = true
end

---@param session Session
function Game:remove_session(session)
    self._sessions[session] = nil
end

---@return Session[] The live sessions in the game (`lifetime.alive`), in no particular order
function Game:get_sessions()
    ---@type Session[]
    local sessions = {}
    for session in pairs(self._sessions) do
        if lifetime.alive(session) then
            table.insert(sessions, session)
        end
    end
    return sessions
end

---@return Session[] The live sessions whose grants changed, each set rebuilt from the data (`Session:refresh_permissions`)
function Game:refresh_permissions()
    ---@type Session[]
    local changed = {}
    for _, session in ipairs(self:get_sessions()) do
        if session:refresh_permissions() then
            table.insert(changed, session)
        end
    end
    return changed
end

return Game

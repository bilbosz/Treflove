local Asset = require("data.asset")
local AssetStore = require("data.asset-store")

---@class Game: Object
---@field private _id string
---@field private _file Asset
---@field private _data GameData
---@field private _store AssetStore
local Game = class("Game")

---@param id string The game's directory name
---@param root string The game's directory, `s/games/<id>`: its `save.lua` is read now
function Game:init(id, root)
    assert_type(id, "string")
    self._id = id
    self._file = Asset(root .. "/save.lua")
    self._data = assert(table.from_string(self._file:read()), "the save of the game " .. id .. " does not load") --[[@as GameData]]
    self._store = AssetStore(root)
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

return Game

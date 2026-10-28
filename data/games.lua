local Asset = require("data.asset")
local Consts = require("app.consts")
local Game = require("game.game")
local fixture = require("data.fixture")

---@class GameInfo One game, as `ListGamesRp` sends it
---@field id string
---@field name string
---@field member boolean Whether the asking login is among the game's players
---@field deletable boolean Whether the asking login may delete the game: a player with `write` on `game` in it

---@class Games: Object
---@field private _root string
---@field private _games table<string, Game> The games loaded so far, by id
local Games = class("Games")

---@param name string
---@return string|nil id The name in lower case, every run of characters outside `[a-z0-9]` one `-`, without a `-` at either end; `nil` when nothing is left
function Games.make_id(name)
    local id = string.gsub(string.lower(name), "[^a-z0-9]+", "-")
    id = string.gsub(id, "^%-+", "")
    id = string.gsub(id, "%-+$", "")
    if id == "" then
        return nil
    end
    return id
end

---@param root string The games' directory, `s/games`: a directory with a `save.lua` per game
function Games:init(root)
    self._root = root
    self._games = {}
end

---@private
---@param id string
---@return string
function Games:_get_directory(id)
    return self._root .. "/" .. id
end

---@private
---@param id string
---@return boolean
function Games:_has_save(id)
    local info = love.filesystem.getInfo(self:_get_directory(id) .. "/save.lua")
    return info ~= nil and info.type == "file"
end

---@return string[] ids Sorted
function Games:list()
    ---@type string[]
    local ids = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(self._root)) do
        if Games.make_id(item) == item and self:_has_save(item) then
            table.insert(ids, item)
        end
    end
    table.sort(ids)
    return ids
end

---@param id string
---@return Game|nil game Loaded at the first call, kept for the next; `nil` when there is no such game
function Games:get(id)
    if type(id) ~= "string" or Games.make_id(id) ~= id then
        return nil
    end
    local game = self._games[id]
    if not game and self:_has_save(id) then
        game = Game(id, self:_get_directory(id))
        self._games[id] = game
    end
    return game
end

---@param name string
---@param creator string The login that becomes the game's master and the owner of its tokens
---@return Game|nil game
---@return string|nil err Why not, for the user
function Games:create(name, creator)
    if type(name) ~= "string" or #name > Consts.GAME_NAME_MAX_LENGTH then
        return nil, string.format("A game's name can have at most %d characters", Consts.GAME_NAME_MAX_LENGTH)
    end
    local id = Games.make_id(name)
    if not id then
        return nil, "A game needs a name with a letter or a digit"
    end
    if love.filesystem.getInfo(self:_get_directory(id)) then
        local existing = self:get(id)
        return nil, string.format("A game named %q exists already", existing and existing:get_name() or name)
    end
    fixture.seed(Consts.GAME_TEMPLATE_DIRECTORY, self:_get_directory(id))
    local game = assert(self:get(id))
    local data = game:get_data()
    data.name = name
    data.players[creator] = {
        group = "master"
    }
    for _, token in pairs(data.tokens) do
        token.owners = token.owners or {}
        table.insert(token.owners, creator)
    end
    game:save()
    return game
end

---@param id string A game `get` gives: its directory, the save and the store under it, is removed
function Games:delete(id)
    assert(self:get(id), "no such game " .. tostring(id))
    self._games[id] = nil
    Asset(self:_get_directory(id)):remove()
end

return Games

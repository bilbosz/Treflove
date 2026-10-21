---@class permissions
local permissions = {}

---@enum permissions.Action
permissions.Action = {
    READ = "read",
    WRITE = "write",
    VIEW = "view"
}

permissions.OWNED = "@owned"

---@class Grant A parsed grant, `<action>[:<kind>[/<key>]]`
---@field action permissions.Action
---@field kind string|nil A key of `GameData`, or `assets`; `nil` for every kind
---@field key string|nil An entry key or `permissions.OWNED`; `nil` for every entry of the kind

---@param text string
---@return permissions.Action|nil
local function _find_action(text)
    for _, action in pairs(permissions.Action) do
        if action == text then
            return action
        end
    end
    return nil
end

---@param text string
---@param reason string
---@return string
local function _malformed(text, reason)
    return string.format("Malformed grant %q: %s", text, reason)
end

---@param text string
---@return Grant
function permissions.parse(text)
    assert_type(text, "string")
    local colon = string.find(text, ":", 1, true)
    local action = _find_action(colon and string.sub(text, 1, colon - 1) or text)
    if not action then
        error(_malformed(text, "unknown action"), 2)
    end
    if not colon then
        return {
            action = action
        }
    end
    local scope = string.sub(text, colon + 1)
    local slash = string.find(scope, "/", 1, true)
    local kind = slash and string.sub(scope, 1, slash - 1) or scope
    if kind == "" then
        error(_malformed(text, "empty kind"), 2)
    end
    if not slash then
        return {
            action = action,
            kind = kind
        }
    end
    local key = string.sub(scope, slash + 1)
    if key == "" then
        error(_malformed(text, "empty key"), 2)
    end
    if string.sub(key, 1, 1) == "@" and key ~= permissions.OWNED then
        error(_malformed(text, "unknown selector"), 2)
    end
    return {
        action = action,
        kind = kind,
        key = key
    }
end

---@param grant Grant
---@return string
function permissions.format(grant)
    assert(grant.kind or not grant.key, "a grant with a key needs a kind")
    ---@type string
    local text = grant.action
    if grant.kind then
        text = text .. ":" .. grant.kind
    end
    if grant.key then
        text = text .. "/" .. grant.key
    end
    return text
end

---@param data GameData
---@param login string
---@return string[] The group's grants followed by the player's own
function permissions.resolve(data, login)
    local player = data.players[login]
    if not player then
        error(string.format("Unknown login %q", login), 2)
    end
    ---@type string[]
    local grants = {}
    local group = data.groups and data.groups[player.group] -- a save from before the groups has none
    if group then
        table.merge_array(grants, group.permissions)
    else
        app:log(string.format("Player %q is in the unknown group %q: no grants from it", login, tostring(player.group)))
    end
    if player.permissions then
        table.merge_array(grants, player.permissions)
    end
    return grants
end

---@generic V
---@param source table<string, V>|nil
---@param set PermissionSet
---@param kind string
---@return table<string, V>
local function _filter_collection(source, set, kind)
    ---@type table<string, any>
    local result = {}
    ---@param key any
    ---@param entry any
    for key, entry in pairs(source or {}) do
        if set:allows(permissions.Action.READ, kind, key) then
            result[key] = table.deep_copy(entry)
        end
    end
    return result
end

---@generic T: table
---@param source T
---@param allowed boolean
---@return T A deep copy, or an empty table when not `allowed`
local function _copy_if(source, allowed)
    ---@type table<any, any>
    local copy = allowed and table.deep_copy(source) or {}
    return copy
end

---@param data GameData
---@param set PermissionSet
---@return GameData A copy for the wire, with only what `set` may read and without the players' `auth`
function permissions.filter(data, set)
    ---@type GameData
    local result = {
        game = _copy_if(data.game, set:allows(permissions.Action.READ, "game")),
        groups = _filter_collection(data.groups, set, "groups"),
        pages = _filter_collection(data.pages, set, "pages"),
        players = _filter_collection(data.players, set, "players"),
        token_properties = _filter_collection(data.token_properties, set, "token_properties"),
        tokens = _filter_collection(data.tokens, set, "tokens")
    }
    for _, page in pairs(result.pages) do
        ---@type string[]
        local tokens = {}
        for _, name in ipairs(page.tokens) do
            if result.tokens[name] then
                table.insert(tokens, name)
            end
        end
        page.tokens = tokens
    end
    for _, player in pairs(result.players) do
        player.auth = nil
    end
    return result
end

return permissions

local permissions = require("game.permissions")

---@class token_id
local token_id = {}

---@type table<TokenPropertyType, type>
local CHANGEABLE_TYPES = {
    string = "string",
    number = "number",
    image = "string"
}

---@param value TokenDataValue|nil
---@return number|nil x `nil` unless the value is a position, a table of two numbers
---@return number|nil y
function token_id.read_position(value)
    if type(value) ~= "table" or #value ~= 2 then
        return nil, nil
    end
    local x, y = value[1], value[2]
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil, nil
    end
    return x, y
end

---@param data GameData
---@param key string
---@param value TokenDataValue
---@return boolean
local function _is_changeable(data, key, value)
    if key == "position" then
        return token_id.read_position(value) ~= nil
    end
    local property = data.token_properties[key]
    return property ~= nil and CHANGEABLE_TYPES[property.type] == type(value)
end

---@param data GameData
---@param changes table<string, TokenDataValue>
---@return string|nil The first key a player cannot set to its value over the wire, one other than the position and the `string`, `number` and `image` properties or a value of the wrong type; `nil` when every one can
function token_id.find_unchangeable(data, changes)
    for key, value in pairs(changes) do
        if type(key) ~= "string" or not _is_changeable(data, key, value) then
            return tostring(key)
        end
    end
    return nil
end

---@param data GameData
---@param id string
---@return string|nil Why `id` cannot be a token's id, for the user; `nil` when it can
function token_id.check(data, id)
    assert_type(id, "string")
    if id == "" then
        return "An id must not be empty"
    end
    if string.sub(id, 1, 1) == "@" then
        return "An id must not start with \"@\""
    end
    if data.tokens[id] ~= nil then
        return string.format("A token with the id %q already exists", id)
    end
    return nil
end

---@param data GameData
---@param id string A key of `data.tokens`
---@param new_id string One `check` accepts
function token_id.rename(data, id, new_id)
    local token = assert(data.tokens[id], string.format("No token with the id %q", id))
    local reason = token_id.check(data, new_id)
    assert(not reason, reason)
    data.tokens[new_id] = token
    data.tokens[id] = nil
    for _, page in pairs(data.pages) do
        for i, page_token in ipairs(page.tokens) do
            if page_token == id then
                page.tokens[i] = new_id
            end
        end
    end
    local kind = permissions.Kind.TOKENS
    for _, group in pairs(data.groups) do
        group.permissions = permissions.rename_key(group.permissions, kind, id, new_id)
    end
    for _, player in pairs(data.players) do
        if player.permissions then
            player.permissions = permissions.rename_key(player.permissions, kind, id, new_id)
        end
    end
end

---@param data GameData
---@param id string A key of `data.tokens`
function token_id.remove(data, id)
    assert(data.tokens[id], string.format("No token with the id %q", id))
    data.tokens[id] = nil
    for _, page in pairs(data.pages) do
        for i = #page.tokens, 1, -1 do
            if page.tokens[i] == id then
                table.remove(page.tokens, i)
            end
        end
    end
    local kind = permissions.Kind.TOKENS
    for _, group in pairs(data.groups) do
        group.permissions = permissions.remove_key(group.permissions, kind, id)
    end
    for _, player in pairs(data.players) do
        if player.permissions then
            player.permissions = permissions.remove_key(player.permissions, kind, id)
        end
    end
end

return token_id

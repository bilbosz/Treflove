local permissions = require("game.permissions")

---@class token_id
local token_id = {}

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

return token_id

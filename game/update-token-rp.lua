local RemoteProcedure = require("networking.remote-procedure")
local permissions = require("game.permissions")
local token_id = require("game.token.token-id")

---@class UpdateTokenRequest: RequestBody
---@field public id string The token's id as the client holds it before the change (the key in `GameData.tokens`)
---@field public new_id string|nil The id the token is renamed to, one `token_id.check` accepts
---@field public changes table<string, TokenDataValue> The fields to set: `position` ({x, y} in page meters) or a key of `GameData.token_properties` whose type is `string`, `number` or `image`

---@class UpdateTokenResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user
---@field public id string As requested
---@field public new_id string|nil As requested
---@field public token TokenData|nil The server's entry after the request, when the session may read it: the state applied on success, what to restore on a refusal

---@class UpdateTokenRp: RemoteProcedure
---@field private _session Session
local UpdateTokenRp = class("UpdateTokenRp", RemoteProcedure)

---@type table<TokenPropertyType, type>
local CHANGEABLE_TYPES = {
    string = "string",
    number = "number",
    image = "string"
}

---@param value TokenDataValue
---@return number|nil x `nil` unless the value is a position, a table of two numbers
---@return number|nil y
local function _read_position(value)
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
        return _read_position(value) ~= nil
    end
    local property = data.token_properties[key]
    return property ~= nil and CHANGEABLE_TYPES[property.type] == type(value)
end

---@param data GameData
---@param changes table<string, TokenDataValue>
---@return string|nil The first key that cannot be changed to its value; `nil` when every one can
local function _find_unchangeable(data, changes)
    for key, value in pairs(changes) do
        if type(key) ~= "string" or not _is_changeable(data, key, value) then
            return tostring(key)
        end
    end
    return nil
end

---@param session Session
function UpdateTokenRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@private
---@param request UpdateTokenRequest
---@param reason string
---@param id string|nil The token's id on the server, when it has one: its entry goes with the refusal if the session may read it
---@return UpdateTokenResponse
function UpdateTokenRp:_refuse(request, reason, id)
    local session = self._session
    ---@type TokenData|nil
    local token
    if id and session:is_allowed(permissions.Action.READ, permissions.Kind.TOKENS, id) then
        token = session:get_game():get_data().tokens[id]
    end
    return {
        success = false,
        error = reason,
        id = request.id,
        new_id = request.new_id,
        token = token
    }
end

---@private
---@param game Game
---@param request UpdateTokenRequest
---@param id string The token's id after the request
function UpdateTokenRp:_push(game, request, id)
    local token = game:get_data().tokens[id]
    for _, session in ipairs(game:get_sessions()) do
        if session ~= self._session and session:is_allowed(permissions.Action.READ, permissions.Kind.TOKENS, id) then
            session:get_token_changed_rp():send_request({
                id = request.id,
                new_id = request.new_id,
                token = token
            })
        end
    end
end

---@param request UpdateTokenRequest
---@return UpdateTokenResponse
function UpdateTokenRp:send_response(request)
    assert(app.is_server)
    local session = self._session
    if not session:is_in_game() then
        return self:_refuse(request, "Not in a game")
    end
    local game = session:get_game()
    local data = game:get_data()
    local id, new_id = request.id, request.new_id
    local entry = data.tokens[id]
    if not entry then
        return self:_refuse(request, string.format("No token with the id %q", tostring(id)))
    end
    if not session:is_allowed(permissions.Action.WRITE, permissions.Kind.TOKENS, id) then
        return self:_refuse(request, string.format("Not allowed to change the token %q", id), id)
    end
    local changes = type(request.changes) == "table" and request.changes or {}
    local unchangeable = _find_unchangeable(data, changes)
    if unchangeable then
        return self:_refuse(request, string.format("Cannot change %q of the token %q", unchangeable, id), id)
    end
    if new_id then
        local reason = token_id.check(data, new_id)
        if reason then
            return self:_refuse(request, reason, id)
        end
        token_id.rename(data, id, new_id)
        for _, other in ipairs(game:get_sessions()) do
            other:get_permissions():rename_key(permissions.Kind.TOKENS, id, new_id)
        end
        id = new_id
    end
    for key, value in pairs(changes) do
        if key == "position" then
            local x, y = _read_position(value)
            entry.position = {
                assert(x),
                assert(y)
            }
        else
            entry[key] = value
        end
    end
    game:save()
    self:_push(game, request, id)
    return {
        success = true,
        id = request.id,
        new_id = new_id,
        token = session:is_allowed(permissions.Action.READ, permissions.Kind.TOKENS, id) and entry or nil
    }
end

---@param response UpdateTokenResponse
function UpdateTokenRp:receive_response(response)
    assert(app.is_client)
    if response.success then
        return
    end
    app.notification_manager:notify(response.error or "Cannot change the token")
    if response.new_id then
        self._session:apply_token(response.new_id, response.id, response.token)
    else
        self._session:apply_token(response.id, nil, response.token)
    end
end

return UpdateTokenRp

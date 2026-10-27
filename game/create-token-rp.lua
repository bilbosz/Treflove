local Asset = require("data.asset")
local RemoteProcedure = require("networking.remote-procedure")
local permissions = require("game.permissions")
local token_id = require("game.token.token-id")

---@class CreateTokenRequest: RequestBody
---@field public id string The new token's id, one `token_id.check` accepts
---@field public page string The page it is placed on: a key of `GameData.pages`
---@field public token TokenData Its entry: `name`, `diameter`, `avatar`, `position` and any `string`, `number` or `image` property; no `owners` (a created token belongs to the game)

---@class CreateTokenResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user
---@field public id string As requested
---@field public page string As requested
---@field public token TokenData|nil The server's entry on success, when the session may read it

---@class CreateTokenRp: RemoteProcedure
---@field private _session Session
local CreateTokenRp = class("CreateTokenRp", RemoteProcedure)

---@type {key: string, accepts: fun(value: TokenDataValue|nil): boolean}[]
local REQUIRED = {
    {
        key = "name",
        accepts = function(value)
            return type(value) == "string"
        end
    },
    {
        key = "diameter",
        accepts = function(value)
            return type(value) == "number" and value > 0
        end
    },
    {
        key = "avatar",
        accepts = function(value)
            return type(value) == "string"
        end
    },
    {
        key = "position",
        accepts = function(value)
            return token_id.read_position(value) ~= nil
        end
    }
}

---@param values table<string, TokenDataValue>
---@return string|nil The first required key missing or malformed, in the order of `REQUIRED`
local function _find_missing(values)
    for _, required in ipairs(REQUIRED) do
        if not required.accepts(values[required.key]) then
            return required.key
        end
    end
    return nil
end

---@param store AssetStore
---@param path string
---@return boolean Whether `path` names a file of the store
local function _is_file(store, path)
    return not Asset.check_path(path) and store:asset(path):get_type() == "file"
end

---@param values table<string, TokenDataValue> Every key settable, the required ones present
---@return TokenData A fresh entry, no table of the request in it
local function _copy_entry(values)
    ---@type table<string, TokenDataValue>
    local entry = {}
    for key, value in pairs(values) do
        if key == "position" then
            local x, y = token_id.read_position(value)
            entry.position = {
                assert(x),
                assert(y)
            }
        else
            entry[key] = value
        end
    end
    return entry --[[@as TokenData]]
end

---@param session Session
function CreateTokenRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@private
---@param request CreateTokenRequest
---@param reason string
---@return CreateTokenResponse
function CreateTokenRp:_refuse(request, reason)
    return {
        success = false,
        error = reason,
        id = request.id,
        page = request.page
    }
end

---@private
---@param game Game
---@param request CreateTokenRequest
---@return string|nil Why the request cannot be applied, for the user; `nil` when it can
function CreateTokenRp:_check(game, request)
    local session = self._session
    local data = game:get_data()
    if not session:is_allowed(permissions.Action.WRITE, permissions.Kind.TOKENS) then
        return "Not allowed to create a token"
    end
    local id = request.id
    if type(id) ~= "string" then
        return "An id must be a string"
    end
    local reason = token_id.check(data, id)
    if reason then
        return reason
    end
    if type(request.page) ~= "string" or not data.pages[request.page] then
        return string.format("No page %q", tostring(request.page))
    end
    ---@type table<string, TokenDataValue>
    local values = type(request.token) == "table" and request.token or {}
    local missing = _find_missing(values)
    if missing then
        return string.format("A new token needs %q", missing)
    end
    local unsettable = token_id.find_unchangeable(data, values)
    if unsettable then
        return string.format("Cannot set %q of a new token", unsettable)
    end
    local avatar = request.token.avatar
    if not _is_file(game:get_store(), avatar) then
        return string.format("No asset %q", avatar)
    end
    return nil
end

---@private
---@param game Game
---@param request CreateTokenRequest
---@param token TokenData
function CreateTokenRp:_push(game, request, token)
    for _, session in ipairs(game:get_sessions()) do
        if session ~= self._session and session:is_allowed(permissions.Action.READ, permissions.Kind.TOKENS, request.id) then
            session:get_token_created_rp():send_request({
                id = request.id,
                page = request.page,
                token = token
            })
        end
    end
end

---@param request CreateTokenRequest
---@return CreateTokenResponse
function CreateTokenRp:send_response(request)
    assert(app.is_server)
    local session = self._session
    if not session:is_in_game() then
        return self:_refuse(request, "Not in a game")
    end
    local game = session:get_game()
    local reason = self:_check(game, request)
    if reason then
        return self:_refuse(request, reason)
    end
    local data = game:get_data()
    local id = request.id
    local entry = _copy_entry(request.token)
    data.tokens[id] = entry
    table.insert(data.pages[request.page].tokens, id)
    game:save()
    self:_push(game, request, entry)
    return {
        success = true,
        id = id,
        page = request.page,
        token = session:is_allowed(permissions.Action.READ, permissions.Kind.TOKENS, id) and entry or nil
    }
end

---@param response CreateTokenResponse
function CreateTokenRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot create the token")
        return
    end
    if response.token and self._session:is_logged_in() then
        self._session:apply_token_created(response.id, response.page, response.token)
    end
end

return CreateTokenRp

local RemoteProcedure = require("networking.remote-procedure")
local permissions = require("game.permissions")
local token_id = require("game.token.token-id")

---@class DeleteTokenRequest: RequestBody
---@field public id string The token's id, a key of `GameData.tokens`

---@class DeleteTokenResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user
---@field public id string As requested

---@class DeleteTokenRp: RemoteProcedure
---@field private _session Session
local DeleteTokenRp = class("DeleteTokenRp", RemoteProcedure)

---@param session Session
function DeleteTokenRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@private
---@param request DeleteTokenRequest
---@param reason string
---@return DeleteTokenResponse
function DeleteTokenRp:_refuse(request, reason)
    return {
        success = false,
        error = reason,
        id = request.id
    }
end

---@private
---@param game Game
---@param id string
---@return Session[] The other sessions of the game that read the token now
function DeleteTokenRp:_find_readers(game, id)
    ---@type Session[]
    local readers = {}
    for _, session in ipairs(game:get_sessions()) do
        if session ~= self._session and session:is_allowed(permissions.Action.READ, permissions.Kind.TOKENS, id) then
            table.insert(readers, session)
        end
    end
    return readers
end

---@param request DeleteTokenRequest
---@return DeleteTokenResponse
function DeleteTokenRp:send_response(request)
    assert(app.is_server)
    local session = self._session
    if not session:is_in_game() then
        return self:_refuse(request, "Not in a game")
    end
    local game = session:get_game()
    local data = game:get_data()
    local id = request.id
    if type(id) ~= "string" or not data.tokens[id] then
        return self:_refuse(request, string.format("No token with the id %q", tostring(id)))
    end
    if not session:is_allowed(permissions.Action.WRITE, permissions.Kind.TOKENS, id) then
        return self:_refuse(request, string.format("Not allowed to delete the token %q", id))
    end
    local readers = self:_find_readers(game, id)
    token_id.remove(data, id)
    for _, other in ipairs(game:get_sessions()) do
        other:get_permissions():remove_key(permissions.Kind.TOKENS, id)
    end
    game:save()
    for _, reader in ipairs(readers) do
        reader:get_token_deleted_rp():send_request({
            id = id
        })
    end
    return {
        success = true,
        id = id
    }
end

---@param response DeleteTokenResponse
function DeleteTokenRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot delete the token")
        return
    end
    if self._session:is_logged_in() then
        self._session:apply_token_deleted(response.id)
    end
end

return DeleteTokenRp

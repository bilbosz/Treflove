local RemoteProcedure = require("networking.remote-procedure")
local entries = require("game.entry.entries")
local permissions = require("game.permissions")

---@class DeleteEntryRequest: RequestBody
---@field public kind EntryKind One `entries.can_delete` accepts
---@field public id string The entry's id

---@class DeleteEntryResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user
---@field public kind EntryKind As requested
---@field public id string As requested

---@class DeleteEntryRp: RemoteProcedure
---@field private _session Session
local DeleteEntryRp = class("DeleteEntryRp", RemoteProcedure)

---@param session Session
function DeleteEntryRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@private
---@param request DeleteEntryRequest
---@param reason string
---@return DeleteEntryResponse
function DeleteEntryRp:_refuse(request, reason)
    return {
        success = false,
        error = reason,
        kind = request.kind,
        id = request.id
    }
end

---@private
---@param game Game
---@param request DeleteEntryRequest
---@return string|nil Why the request cannot be applied, for the user; `nil` when it can
function DeleteEntryRp:_check(game, request)
    local data = game:get_data()
    local kind, id = request.kind, request.id
    if not entries.is_kind(kind) then
        return string.format("No kind %q", tostring(kind))
    end
    if type(id) ~= "string" or not entries.get(data, kind, id) then
        return string.format("No %s with the id %q", entries.get_noun(kind), tostring(id))
    end
    if not self._session:is_allowed(permissions.Action.WRITE, entries.get_permission_kind(kind), id) then
        return string.format("Not allowed to delete %s", entries.describe(kind, id))
    end
    return entries.check_delete(data, kind, id)
end

---@private
---@param game Game
---@param kind EntryKind
---@param id string
---@return Session[] The other sessions of the game that read the entry now
function DeleteEntryRp:_find_readers(game, kind, id)
    ---@type Session[]
    local readers = {}
    for _, session in ipairs(game:get_sessions()) do
        if session ~= self._session and session:is_allowed(permissions.Action.READ, entries.get_permission_kind(kind), id) then
            table.insert(readers, session)
        end
    end
    return readers
end

---@param request DeleteEntryRequest
---@return DeleteEntryResponse
function DeleteEntryRp:send_response(request)
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
    local kind, id = request.kind, request.id
    local readers = self:_find_readers(game, kind, id)
    entries.remove(game:get_data(), kind, id)
    local changed = game:refresh_permissions()
    game:save()
    for _, reader in ipairs(readers) do
        reader:get_entry_deleted_rp():send_request({
            kind = kind,
            id = id
        })
    end
    for _, other in ipairs(changed) do
        other:get_grants_changed_rp():send_request({
            permissions = other:get_permissions():get_grants()
        })
    end
    return {
        success = true,
        kind = kind,
        id = id
    }
end

---@param response DeleteEntryResponse
function DeleteEntryRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot delete the entry")
        return
    end
    if self._session:is_logged_in() then
        self._session:apply_entry_deleted(response.kind, response.id)
    end
end

return DeleteEntryRp

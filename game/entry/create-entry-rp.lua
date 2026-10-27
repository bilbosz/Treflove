local RemoteProcedure = require("networking.remote-procedure")
local entries = require("game.entry.entries")
local permissions = require("game.permissions")

---@class CreateEntryRequest: RequestBody
---@field public kind EntryKind One `entries.can_create` accepts
---@field public id string The new entry's id, one `entries.check_id` accepts
---@field public entry EntryData|EntryValues Its fields, ones `entries.check_new` accepts

---@class CreateEntryResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user
---@field public kind EntryKind As requested
---@field public id string As requested
---@field public entry EntryData|nil The server's entry on success, when the session may read it

---@class CreateEntryRp: RemoteProcedure
---@field private _session Session
local CreateEntryRp = class("CreateEntryRp", RemoteProcedure)

---@param session Session
function CreateEntryRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@private
---@param request CreateEntryRequest
---@param reason string
---@return CreateEntryResponse
function CreateEntryRp:_refuse(request, reason)
    return {
        success = false,
        error = reason,
        kind = request.kind,
        id = request.id
    }
end

---@private
---@param game Game
---@param request CreateEntryRequest
---@return string|nil Why the request cannot be applied, for the user; `nil` when it can
function CreateEntryRp:_check(game, request)
    local data = game:get_data()
    local kind = request.kind
    if not entries.is_kind(kind) then
        return string.format("No kind %q", tostring(kind))
    end
    if not entries.can_create(kind) then
        return entries.check_id(data, kind, request.id)
    end
    if not self._session:is_allowed(permissions.Action.WRITE, entries.get_permission_kind(kind)) then
        return string.format("Not allowed to create a %s", entries.get_noun(kind))
    end
    return entries.check_id(data, kind, request.id) or entries.check_new(data, kind, request.entry, game:get_store())
end

---@private
---@param game Game
---@param request CreateEntryRequest
---@param entry EntryData
---@param changed Session[] The sessions whose grants changed
function CreateEntryRp:_push(game, request, entry, changed)
    local kind = request.kind
    for _, session in ipairs(game:get_sessions()) do
        if session ~= self._session and session:is_allowed(permissions.Action.READ, entries.get_permission_kind(kind), request.id) then
            session:get_entry_created_rp():send_request({
                kind = kind,
                id = request.id,
                entry = entry
            })
        end
    end
    for _, session in ipairs(changed) do
        session:get_grants_changed_rp():send_request({
            permissions = session:get_permissions():get_grants()
        })
    end
end

---@param request CreateEntryRequest
---@return CreateEntryResponse
function CreateEntryRp:send_response(request)
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
    local entry = entries.create(game:get_data(), kind, id, request.entry)
    local changed = game:refresh_permissions()
    game:save()
    self:_push(game, request, entry, changed)
    return {
        success = true,
        kind = kind,
        id = id,
        entry = session:is_allowed(permissions.Action.READ, entries.get_permission_kind(kind), id) and entry or nil
    }
end

---@param response CreateEntryResponse
function CreateEntryRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot create the entry")
        return
    end
    if response.entry and self._session:is_logged_in() then
        self._session:apply_entry_created(response.kind, response.id, response.entry)
    end
end

return CreateEntryRp

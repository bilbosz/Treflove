local RemoteProcedure = require("networking.remote-procedure")
local entries = require("game.entry.entries")
local permissions = require("game.permissions")

---@class UpdateEntryRequest: RequestBody
---@field public kind EntryKind
---@field public id string The entry's id as the client holds it, `entries.GAME_ID` for `game`
---@field public new_id string|nil The id the entry is renamed to, one `entries.check_rename` accepts
---@field public changes EntryValues The fields to set, ones `entries.check_changes` accepts

---@class UpdateEntryResponse: ResponseBody
---@field public success boolean
---@field public error string|nil Why not, for the user
---@field public kind EntryKind As requested
---@field public id string As requested
---@field public new_id string|nil As requested
---@field public entry EntryData|nil The server's entry after the request (under `new_id` when renamed), when the session may read it

---@class UpdateEntryRp: RemoteProcedure
---@field private _session Session
local UpdateEntryRp = class("UpdateEntryRp", RemoteProcedure)

---@param session Session
function UpdateEntryRp:init(session)
    RemoteProcedure.init(self, session:get_connection())
    self._session = session
end

---@private
---@param request UpdateEntryRequest
---@param reason string
---@param id string|nil The entry's id on the server, when it has one: the entry goes with the refusal if the session may read it
---@return UpdateEntryResponse
function UpdateEntryRp:_refuse(request, reason, id)
    local session = self._session
    ---@type EntryData|nil
    local entry
    if id and session:is_allowed(permissions.Action.READ, entries.get_permission_kind(request.kind), id) then
        entry = entries.get(session:get_game():get_data(), request.kind, id)
    end
    return {
        success = false,
        error = reason,
        kind = request.kind,
        id = request.id,
        new_id = request.new_id,
        entry = entry
    }
end

---@private
---@param game Game
---@param request UpdateEntryRequest
---@return string|nil reason Why the request cannot be applied, for the user; `nil` when it can
---@return string|nil id The entry's id on the server, when it has one
function UpdateEntryRp:_check(game, request)
    local session = self._session
    local data = game:get_data()
    local kind, id, new_id = request.kind, request.id, request.new_id
    if not entries.is_kind(kind) then
        return string.format("No kind %q", tostring(kind)), nil
    end
    if type(id) ~= "string" or not entries.get(data, kind, id) then
        return string.format("No %s with the id %q", entries.get_noun(kind), tostring(id)), nil
    end
    if not session:is_allowed(permissions.Action.WRITE, entries.get_permission_kind(kind), id) then
        return string.format("Not allowed to change %s", entries.describe(kind, id)), id
    end
    if new_id ~= nil then
        local reason = entries.check_rename(data, kind, id, new_id)
        if reason then
            return reason, id
        end
    end
    return entries.check_changes(data, kind, id, request.changes or {}, game:get_store()), id
end

---@private
---@param game Game
---@param request UpdateEntryRequest
---@param id string The entry's id after the request
---@param changed Session[] The sessions whose grants changed
function UpdateEntryRp:_push(game, request, id, changed)
    local kind = request.kind
    local entry = assert(entries.get(game:get_data(), kind, id))
    for _, session in ipairs(game:get_sessions()) do
        if session ~= self._session and session:is_allowed(permissions.Action.READ, entries.get_permission_kind(kind), id) then
            session:get_entry_changed_rp():send_request({
                kind = kind,
                id = request.id,
                new_id = request.new_id,
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

---@param request UpdateEntryRequest
---@return UpdateEntryResponse
function UpdateEntryRp:send_response(request)
    assert(app.is_server)
    local session = self._session
    if not session:is_in_game() then
        return self:_refuse(request, "Not in a game")
    end
    local game = session:get_game()
    local reason, id = self:_check(game, request)
    if reason then
        return self:_refuse(request, reason, id)
    end
    id = assert(id)
    local data = game:get_data()
    local kind, new_id = request.kind, request.new_id
    if new_id then
        entries.rename(data, kind, id, new_id)
        id = new_id
    end
    entries.apply(data, kind, id, request.changes or {})
    local changed = game:refresh_permissions()
    game:save()
    self:_push(game, request, id, changed)
    return {
        success = true,
        kind = kind,
        id = request.id,
        new_id = new_id,
        entry = session:is_allowed(permissions.Action.READ, entries.get_permission_kind(kind), id) and entries.get(data, kind, id) or nil
    }
end

---@param response UpdateEntryResponse
function UpdateEntryRp:receive_response(response)
    assert(app.is_client)
    if not response.success then
        app.notification_manager:notify(response.error or "Cannot change the entry")
        return
    end
    if self._session:is_logged_in() then
        self._session:apply_entry(response.kind, response.id, response.new_id, response.entry)
    end
end

return UpdateEntryRp

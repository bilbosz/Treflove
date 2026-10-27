local Asset = require("data.asset")
local permissions = require("game.permissions")

---@alias EntryKind "game"|"pages"|"groups"|"players"|"token_properties" A collection of `GameData` by its key, or the `game` entry; the same strings as `permissions.Kind`
---@alias EntryData GameScreenData|PageData|GroupData|PlayerData|TokenProperty
---@alias EntryValue string|number|string[] The value of one field of an entry over the wire
---@alias EntryValues table<string, EntryValue> Fields of an entry by their keys, as a change or a new entry carries them
---@alias EntryFieldType "string"|"number"|"image"|"grants"|"enum"|"group"|"page"

---@class EntryField
---@field key string
---@field title string What the panel shows above the field
---@field type EntryFieldType
---@field required boolean A creation must carry it (an absent `grants` field defaults to `{}`)
---@field options string[]|nil For `enum`: the accepted values

---@class entries
local entries = {}

entries.GAME_ID = "game"

---@type EntryKind[]
entries.KINDS = {
    "game",
    "pages",
    "groups",
    "players",
    "token_properties"
}

---@type table<string, boolean> The keys every token has
entries.PROTECTED_PROPERTIES = {
    name = true,
    diameter = true,
    avatar = true,
    position = true
}

---@type table<EntryKind, EntryField[]>
entries.FIELDS = {
    game = {
        {
            key = "page",
            title = "Page",
            type = "page",
            required = true
        }
    },
    pages = {
        {
            key = "name",
            title = "Name",
            type = "string",
            required = true
        },
        {
            key = "width",
            title = "Width",
            type = "number",
            required = true
        },
        {
            key = "pixel_per_meter",
            title = "Pixels per meter",
            type = "number",
            required = true
        },
        {
            key = "image",
            title = "Image",
            type = "image",
            required = true
        }
    },
    groups = {
        {
            key = "title",
            title = "Title",
            type = "string",
            required = true
        },
        {
            key = "permissions",
            title = "Permissions",
            type = "grants",
            required = true
        }
    },
    players = {
        {
            key = "group",
            title = "Group",
            type = "group",
            required = false
        },
        {
            key = "permissions",
            title = "Permissions",
            type = "grants",
            required = false
        }
    },
    token_properties = {
        {
            key = "title",
            title = "Title",
            type = "string",
            required = true
        },
        {
            key = "type",
            title = "Type",
            type = "enum",
            required = true,
            options = {
                "string",
                "number",
                "image",
                "array"
            }
        }
    }
}

---@type table<EntryKind, permissions.Kind>
local PERMISSION_KINDS = {
    game = permissions.Kind.GAME,
    pages = permissions.Kind.PAGES,
    groups = permissions.Kind.GROUPS,
    players = permissions.Kind.PLAYERS,
    token_properties = permissions.Kind.TOKEN_PROPERTIES
}

---@type table<EntryKind, string>
local NOUNS = {
    game = "game",
    pages = "page",
    groups = "group",
    players = "player",
    token_properties = "token property"
}

---@type table<EntryKind, string>
local PLURALS = {
    game = "The game",
    pages = "Pages",
    groups = "Groups",
    players = "Players",
    token_properties = "Token properties"
}

---@type table<EntryKind, boolean>
local CHANGEABLE_KINDS = {
    pages = true,
    groups = true,
    token_properties = true
}

---@param value string
---@return boolean Whether `value` is one of `entries.KINDS`
function entries.is_kind(value)
    return table.find_array_idx(entries.KINDS, value) ~= nil
end

---@param kind EntryKind
---@return permissions.Kind The kind the grants on the entries of `kind` name
function entries.get_permission_kind(kind)
    return PERMISSION_KINDS[kind]
end

---@param kind EntryKind
---@param id string|nil
---@return string For the user: `the page "P"`, `the game`
function entries.describe(kind, id)
    if kind == "game" then
        return "the game"
    end
    return string.format("the %s %q", NOUNS[kind], tostring(id))
end

---@param kind EntryKind
---@return string What one entry of the kind is called: `page`, `token property`
function entries.get_noun(kind)
    return NOUNS[kind]
end

---@param kind EntryKind
---@param key string
---@return EntryField|nil
function entries.find_field(kind, key)
    for _, field in ipairs(entries.FIELDS[kind]) do
        if field.key == key then
            return field
        end
    end
    return nil
end

---@param kind EntryKind
---@return boolean
function entries.can_create(kind)
    return CHANGEABLE_KINDS[kind] == true
end

---@param kind EntryKind
---@return boolean
function entries.can_delete(kind)
    return CHANGEABLE_KINDS[kind] == true
end

---@param kind EntryKind
---@return boolean
function entries.can_rename(kind)
    return CHANGEABLE_KINDS[kind] == true
end

---@param data GameData
---@param kind EntryKind A kind other than `game`
---@return table<string, EntryData>|nil The collection, `nil` when the data has none
local function _get_collection(data, kind)
    ---@type table<string, table<string, EntryData>|nil>
    local collections = data
    return collections[kind]
end

---@param data GameData
---@param kind EntryKind
---@return string[] The ids the data holds, sorted; `{entries.GAME_ID}` for `game`
function entries.list(data, kind)
    if kind == "game" then
        return {
            entries.GAME_ID
        }
    end
    ---@type string[]
    local ids = {}
    for id in pairs(_get_collection(data, kind) or {}) do
        table.insert(ids, id)
    end
    table.sort(ids)
    return ids
end

---@param data GameData
---@param kind EntryKind
---@param id string
---@return EntryData|nil
function entries.get(data, kind, id)
    if kind == "game" then
        return id == entries.GAME_ID and data.game or nil
    end
    local collection = _get_collection(data, kind)
    return collection and collection[id]
end

---@param data GameData
---@param key string
---@return boolean Whether any token holds the key
function entries.is_property_held(data, key)
    for _, token in pairs(data.tokens or {}) do
        if token[key] ~= nil then
            return true
        end
    end
    return false
end

---@param data GameData
---@param kind EntryKind
---@param id string Checked to be one, as it comes over the wire
---@return string|nil Why `id` cannot be a new id of the kind, for the user; `nil` when it can
function entries.check_id(data, kind, id)
    if not entries.can_create(kind) then
        return PLURALS[kind] .. " cannot be created"
    end
    if type(id) ~= "string" then
        return "An id must be a string"
    end
    if id == "" then
        return "An id must not be empty"
    end
    if string.sub(id, 1, 1) == "@" then
        return "An id must not start with \"@\""
    end
    if entries.get(data, kind, id) ~= nil then
        return string.format("A %s with the id %q already exists", NOUNS[kind], id)
    end
    return nil
end

---@param value EntryValue
---@return boolean Whether `value` is an array of strings, nothing else in it
local function _is_string_array(value)
    if type(value) ~= "table" then
        return false
    end
    local count = #value
    for k, v in pairs(value) do
        if type(k) ~= "number" or k < 1 or k > count or k % 1 ~= 0 or type(v) ~= "string" then
            return false
        end
    end
    return true
end

---@param store AssetStore
---@param path string
---@return boolean Whether `path` names a file of the store
local function _is_file(store, path)
    return not Asset.check_path(path) and store:asset(path):get_type() == "file"
end

---@param data GameData
---@param field EntryField
---@param value EntryValue
---@param store AssetStore|nil
---@return string|nil Why `value` cannot be the field's, for the user
local function _check_value(data, field, value, store)
    local title, kind = field.title, field.type
    if kind == "number" then
        if type(value) ~= "number" or not (value > 0 and value < math.huge) then
            return title .. " must be a positive number"
        end
        return nil
    end
    if kind == "grants" then
        if type(value) ~= "table" or not _is_string_array(value) then
            return title .. " must be a list of grants"
        end
        for _, text in ipairs(value) do
            ---@type boolean, any
            local ok, err = pcall(permissions.parse, text)
            if not ok then
                return tostring(err)
            end
        end
        return nil
    end
    if type(value) ~= "string" then
        return title .. " must be a string"
    end
    if field.required and value == "" then
        return title .. " must not be empty"
    end
    if kind == "image" then
        if store and not _is_file(store, value) then
            return string.format("No asset %q", value)
        end
    elseif kind == "enum" then
        if not table.find_array_idx(assert(field.options), value) then
            return string.format("%s must be one of %s", title, table.concat(assert(field.options), ", "))
        end
    elseif kind == "group" then
        if not (data.groups or {})[value] then
            return string.format("No group %q", value)
        end
    elseif kind == "page" then
        if not (data.pages or {})[value] then
            return string.format("No page %q", value)
        end
    end
    return nil
end

---@param data GameData
---@param id string The token property's key
---@param value EntryValue The type it would get
---@return string|nil Why the type of an existing token property cannot become `value`
local function _check_property_type(data, id, value)
    local property = data.token_properties[id]
    if not property or property.type == value then
        return nil
    end
    if entries.PROTECTED_PROPERTIES[id] then
        return string.format("%q is a property every token has: its type cannot change", id)
    end
    if entries.is_property_held(data, id) then
        return string.format("The type of %q cannot change while a token holds it", id)
    end
    return nil
end

---@param data GameData
---@param kind EntryKind
---@param id string|nil The entry's id, `nil` for a new one
---@param values EntryValues
---@param store AssetStore|nil
---@return string|nil
local function _check_values(data, kind, id, values, store)
    ---@type string[]
    local unknown = {}
    for key in pairs(values) do
        if type(key) ~= "string" or not entries.find_field(kind, key) then
            table.insert(unknown, tostring(key))
        end
    end
    if #unknown > 0 then
        table.sort(unknown)
        if id then
            return string.format("Cannot change %q of %s", unknown[1], entries.describe(kind, id))
        end
        return string.format("Cannot set %q of a new %s", unknown[1], NOUNS[kind])
    end
    for _, field in ipairs(entries.FIELDS[kind]) do
        local value = values[field.key]
        if value ~= nil then
            local reason = _check_value(data, field, value, store)
            if reason then
                return reason
            end
            if kind == "token_properties" and field.key == "type" and id then
                reason = _check_property_type(data, id, value)
                if reason then
                    return reason
                end
            end
        end
    end
    return nil
end

---@param data GameData
---@param kind EntryKind
---@param id string An entry the data holds
---@param changes EntryValues
---@param store AssetStore|nil The game's: an image must be one of its files
---@return string|nil Why `changes` cannot be applied to the entry, for the user; `nil` when they can
function entries.check_changes(data, kind, id, changes, store)
    if type(changes) ~= "table" then
        return "Changes must be a table"
    end
    return _check_values(data, kind, id, changes, store)
end

---@param data GameData
---@param kind EntryKind
---@param entry EntryData|EntryValues
---@param store AssetStore|nil The game's: an image must be one of its files
---@return string|nil Why `entry` cannot be created, for the user; `nil` when it can
function entries.check_new(data, kind, entry, store)
    if not entries.can_create(kind) then
        return PLURALS[kind] .. " cannot be created"
    end
    ---@type EntryValues
    local values = type(entry) == "table" and entry or {}
    for _, field in ipairs(entries.FIELDS[kind]) do
        if field.required and field.type ~= "grants" and values[field.key] == nil then
            return string.format("A new %s needs %q", NOUNS[kind], field.key)
        end
    end
    return _check_values(data, kind, nil, values, store)
end

---@param data GameData
---@param kind EntryKind
---@param id string
---@return string|nil Why the entry cannot be deleted, for the user; `nil` when it can
function entries.check_delete(data, kind, id)
    if not entries.can_delete(kind) then
        return PLURALS[kind] .. " cannot be deleted"
    end
    local entry = type(id) == "string" and entries.get(data, kind, id)
    if not entry then
        return string.format("No %s with the id %q", NOUNS[kind], tostring(id))
    end
    if kind == "pages" then
        if data.game and data.game.page == id then
            return string.format("The page %q is shown to the players", id)
        end
        if #data.pages[id].tokens > 0 then
            return string.format("The page %q still holds tokens", id)
        end
    elseif kind == "groups" then
        for _, player in pairs(data.players or {}) do
            if player.group == id then
                return string.format("A player is in the group %q", id)
            end
        end
    elseif kind == "token_properties" then
        if entries.PROTECTED_PROPERTIES[id] then
            return string.format("%q is a property every token has", id)
        end
        if entries.is_property_held(data, id) then
            return string.format("A token holds the property %q", id)
        end
    end
    return nil
end

---@param data GameData
---@param kind EntryKind
---@param id string
---@param new_id string Checked to be one, as it comes over the wire
---@return string|nil Why the entry cannot be renamed to `new_id`, for the user; `nil` when it can
function entries.check_rename(data, kind, id, new_id)
    if not entries.can_rename(kind) then
        return PLURALS[kind] .. " cannot be renamed"
    end
    if kind == "token_properties" and entries.PROTECTED_PROPERTIES[id] then
        return string.format("%q is a property every token has: it keeps its key", id)
    end
    return entries.check_id(data, kind, new_id)
end

---@param data GameData
---@param rewrite fun(grants: string[]): string[]
local function _rewrite_grants(data, rewrite)
    for _, group in pairs(data.groups or {}) do
        group.permissions = rewrite(group.permissions)
    end
    for _, player in pairs(data.players or {}) do
        if player.permissions then
            player.permissions = rewrite(player.permissions)
        end
    end
end

---@param value EntryValue
---@return EntryValue A copy of an array, the value itself otherwise
local function _copy_value(value)
    if type(value) == "table" then
        return table.copy(value)
    end
    return value
end

---@param data GameData
---@param kind EntryKind
---@param id string An entry the data holds
---@param new_id string One `check_rename` accepts
function entries.rename(data, kind, id, new_id)
    local collection = assert(_get_collection(data, kind), "no collection " .. kind)
    local entry = assert(collection[id], string.format("No %s with the id %q", NOUNS[kind], id))
    local reason = entries.check_rename(data, kind, id, new_id)
    assert(not reason, reason)
    collection[new_id] = entry
    collection[id] = nil
    if kind == "pages" then
        if data.game and data.game.page == id then
            data.game.page = new_id
        end
    elseif kind == "groups" then
        for _, player in pairs(data.players or {}) do
            if player.group == id then
                player.group = new_id
            end
        end
    elseif kind == "token_properties" then
        for _, token in pairs(data.tokens or {}) do
            if token[id] ~= nil then
                token[new_id] = token[id]
                token[id] = nil
            end
        end
    end
    local permission_kind = PERMISSION_KINDS[kind]
    _rewrite_grants(data, function(grants)
        return permissions.rename_key(grants, permission_kind, id, new_id)
    end)
end

---@param data GameData
---@param kind EntryKind
---@param id string An entry the data holds
function entries.remove(data, kind, id)
    local collection = assert(_get_collection(data, kind), "no collection " .. kind)
    assert(collection[id], string.format("No %s with the id %q", NOUNS[kind], id))
    collection[id] = nil
    local permission_kind = PERMISSION_KINDS[kind]
    _rewrite_grants(data, function(grants)
        return permissions.remove_key(grants, permission_kind, id)
    end)
end

---@param data GameData
---@param kind EntryKind
---@param id string An entry the data holds
---@param changes EntryValues What `check_changes` accepts
function entries.apply(data, kind, id, changes)
    ---@type EntryValues
    local entry = assert(entries.get(data, kind, id), string.format("No %s with the id %q", NOUNS[kind], id))
    for key, value in pairs(changes) do
        entry[key] = _copy_value(value)
    end
end

---@param data GameData
---@param kind EntryKind One `can_create` accepts
---@param id string One `check_id` accepts
---@param entry EntryData|EntryValues One `check_new` accepts
---@return EntryData The entry stored: the fields of the kind copied, the defaults filled in
function entries.create(data, kind, id, entry)
    assert(entries.can_create(kind), PLURALS[kind] .. " cannot be created")
    ---@type EntryValues
    local values = entry
    ---@type EntryValues
    local created = {}
    for _, field in ipairs(entries.FIELDS[kind]) do
        local value = values[field.key]
        if value ~= nil then
            created[field.key] = _copy_value(value)
        elseif field.type == "grants" then
            created[field.key] = {}
        end
    end
    if kind == "pages" then
        created.tokens = {}
    end
    ---@type table<string, EntryValues>
    local collection = assert(_get_collection(data, kind), "no collection " .. kind)
    collection[id] = created
    return assert(entries.get(data, kind, id))
end

return entries

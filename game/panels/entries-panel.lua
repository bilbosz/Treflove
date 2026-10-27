local SidePanel = require("game.side-panel")
local Consts = require("app.consts")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")
local TextInput = require("ui.text-input")
local NumberInput = require("ui.number-input")
local TextButton = require("ui.text-button")
local ScrollView = require("ui.scroll-view")
local entries = require("game.entry.entries")
local lifetime = require("lifetime")
local media = require("utils.media")
local permissions = require("game.permissions")

---@class EntriesPanelField
---@field def EntryField
---@field title Text
---@field input TextInput|NumberInput A `NumberInput` for a `number` field, read-only for an `image` field
---@field button TextButton|nil For an `image` field: opens the assets workspace at the image, to browse for another or, read-only, to show it

---@alias EntriesPanelTexts {id: string|nil, fields: table<string, string>} What the fields hold, kept across a rebuild

---@class EntriesPanel: SidePanel
---@field private _kind EntryKind
---@field private _selected string|nil The id of the entry the fields show
---@field private _is_new boolean Whether the fields hold a new entry, which the next Apply creates
---@field private _list_view ScrollView
---@field private _list_border Rectangle
---@field private _list_buttons TextButton[] One per id, in the order of `entries.list`
---@field private _list_scroll number The list's vertical scroll its buttons were last enabled for
---@field private _fields_view ScrollView Holds the id field and the fields, between the list and the buttons
---@field private _id_title Text|nil Set while an entry is selected or new
---@field private _id_input TextInput|nil Set while an entry is selected or new
---@field private _fields EntriesPanelField[]
---@field private _new_button TextButton|nil Present for a kind the player may create
---@field private _delete_button TextButton|nil Present for a selected entry the player may delete
---@field private _cancel_button TextButton|nil
---@field private _apply_button TextButton|nil Present for a new entry or a selected one the player may write
local EntriesPanel = class("EntriesPanel", SidePanel)

---@param text string
---@return string[]
local function _split_grants(text)
    ---@type string[]
    local grants = {}
    for grant in string.gmatch(text, "%S+") do
        table.insert(grants, grant)
    end
    return grants
end

---@param def EntryField
---@param value EntryValue|nil
---@return EntryValue|nil As the field shows it: an absent text is empty, absent grants are none
local function _normalize(def, value)
    if value ~= nil or def.type == "number" then
        return value
    end
    if def.type == "grants" then
        return {}
    end
    return ""
end

---@param a EntryValue|nil
---@param b EntryValue|nil
---@return boolean
local function _equal(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

---@param game_screen GameScreen
---@param width number
---@param height number
---@param kind EntryKind
function EntriesPanel:init(game_screen, width, height, kind)
    SidePanel.init(self, game_screen, width, height)
    self._kind = kind
    self._selected = nil
    self._is_new = false
    self._list_view = ScrollView(self, width, height, true)
    self._list_border = Rectangle(self, width, height, Consts.FOREGROUND_COLOR, true)
    self._list_buttons = {}
    self._list_scroll = 0
    self._fields_view = ScrollView(self, width, height, true)
    self._id_title = nil
    self._id_input = nil
    self._fields = {}
    self._new_button = nil
    self._delete_button = nil
    self._cancel_button = nil
    self._apply_button = nil
    app.update_event:register(self, self.on_update)
    self:_update_view(nil)
end

---@return EntryKind
function EntriesPanel:get_kind()
    return self._kind
end

---@return string|nil
function EntriesPanel:get_selected()
    return self._selected
end

---@return boolean
function EntriesPanel:is_new()
    return self._is_new
end

---@return TextButton[] One per id, sorted
function EntriesPanel:get_list_buttons()
    return table.copy(self._list_buttons)
end

---@return TextInput|nil
function EntriesPanel:get_id_input()
    return self._id_input
end

---@param key string
---@return TextInput|NumberInput|nil
function EntriesPanel:get_field_input(key)
    for _, field in ipairs(self._fields) do
        if field.def.key == key then
            return field.input
        end
    end
    return nil
end

---@param key string An `image` field
---@return TextButton|nil
function EntriesPanel:get_field_button(key)
    for _, field in ipairs(self._fields) do
        if field.def.key == key then
            return field.button
        end
    end
    return nil
end

---@return TextButton|nil
function EntriesPanel:get_new_button()
    return self._new_button
end

---@return TextButton|nil
function EntriesPanel:get_delete_button()
    return self._delete_button
end

---@return TextButton
function EntriesPanel:get_cancel_button()
    return assert(self._cancel_button)
end

---@return TextButton|nil
function EntriesPanel:get_apply_button()
    return self._apply_button
end

---@param w number
---@param h number
function EntriesPanel:on_resize(w, h)
    SidePanel.on_resize(self, w, h)
    self:_update_view(self:_get_texts())
end

---@param dt number
function EntriesPanel:on_update(dt)
    local _, scroll = self._list_view:get_scroll()
    if scroll ~= self._list_scroll then
        self:_disable_list_buttons_out_of_view()
    end
end

---@param kind EntryKind
---@param id string The entry's id after the change; the deleted one's for a deletion
function EntriesPanel:on_entries_change(kind, id)
    if kind ~= self._kind then
        return
    end
    local data = assert(app.data)
    local refill = false
    if self._is_new then
        if self._id_input and self._id_input:get_text() == id and entries.get(data, kind, id) then
            self._is_new = false
            self._selected = id
            refill = true
        end
    elseif self._selected then
        if not entries.get(data, kind, self._selected) then
            self._selected = entries.get(data, kind, id) and id or nil
            refill = true
        elseif self._selected == id then
            refill = true
        end
    end
    self:_update_view(not refill and self:_get_texts() or nil)
end

function EntriesPanel:on_grants_change()
    if self._is_new and not self:_may_create() then
        self._is_new = false
        self:_update_view(nil)
    else
        self:_update_view(self:_get_texts())
    end
end

---@param id string|nil An id of the kind, `nil` for no selection
function EntriesPanel:select(id)
    self._selected = id
    self._is_new = false
    self:_update_view(nil)
end

function EntriesPanel:start_new()
    if not self:_may_create() then
        return
    end
    self._selected = nil
    self._is_new = true
    self:_update_view(nil)
end

function EntriesPanel:cancel()
    if self._is_new then
        self._is_new = false
        self._selected = nil
    end
    self:_update_view(nil)
end

function EntriesPanel:apply()
    if not self:_is_editable() then
        return
    end
    local missing_number = self:_find_missing_number()
    if missing_number then
        app.notification_manager:notify(missing_number .. " needs a number")
        return
    end
    if self._is_new then
        self:_apply_new()
    else
        self:_apply_changes()
    end
end

function EntriesPanel:delete()
    local id = self._selected
    if not id or not self:_may_delete(id) then
        return
    end
    local reason = entries.check_delete(assert(app.data), self._kind, id)
    if reason then
        app.notification_manager:notify(reason)
        return
    end
    assert(app.session):delete_entry(self._kind, id)
end

---@private
function EntriesPanel:_apply_new()
    local data = assert(app.data)
    local id = assert(self._id_input):get_text()
    local entry = self:_read_fields() --[[@as EntryData]]
    local reason = entries.check_id(data, self._kind, id) or entries.check_new(data, self._kind, entry)
    if reason then
        app.notification_manager:notify(reason)
        return
    end
    assert(app.session):create_entry(self._kind, id, entry)
end

---@private
function EntriesPanel:_apply_changes()
    local data = assert(app.data)
    local id = assert(self._selected)
    local new_id = self:_read_new_id()
    if new_id then
        local reason = entries.check_rename(data, self._kind, id, new_id)
        if reason then
            app.notification_manager:notify(reason)
            return
        end
    end
    local changes = self:_find_changes()
    local reason = entries.check_changes(data, self._kind, id, changes)
    if reason then
        app.notification_manager:notify(reason)
        return
    end
    if new_id or next(changes) ~= nil then
        assert(app.session):update_entry(self._kind, id, changes, new_id)
    end
end

---@private
---@return string|nil The id typed in an editable Id field, when it differs from the selected entry's
function EntriesPanel:_read_new_id()
    local input = self._id_input
    if not input or input:is_read_only() then
        return nil
    end
    local text = input:get_text()
    if text == self._selected then
        return nil
    end
    return text
end

---@private
---@return table<string, EntryValue> Every field's value, after `_find_missing_number` found none missing
function EntriesPanel:_read_fields()
    ---@type table<string, EntryValue>
    local values = {}
    for _, field in ipairs(self._fields) do
        local input = field.input
        local t = field.def.type
        if t == "number" then
            ---@cast input NumberInput
            values[field.def.key] = assert(input:get_number())
        elseif t == "grants" then
            values[field.def.key] = _split_grants(input:get_text())
        else
            values[field.def.key] = input:get_text()
        end
    end
    return values
end

---@private
---@return table<string, EntryValue> The fields whose value differs from the selected entry's
function EntriesPanel:_find_changes()
    ---@type table<string, EntryValue|nil>
    local entry = assert(entries.get(assert(app.data), self._kind, assert(self._selected)))
    ---@type table<string, EntryValue>
    local changes = {}
    for key, value in pairs(self:_read_fields()) do
        local def = assert(self:_find_def(key))
        if not _equal(value, _normalize(def, entry[key])) then
            changes[key] = value
        end
    end
    return changes
end

---@private
---@param key string
---@return EntryField|nil
function EntriesPanel:_find_def(key)
    for _, def in ipairs(entries.FIELDS[self._kind]) do
        if def.key == key then
            return def
        end
    end
    return nil
end

---@private
---@return string|nil The title of the first number field holding no number, which refuses the whole apply
function EntriesPanel:_find_missing_number()
    for _, field in ipairs(self._fields) do
        local input = field.input
        if field.def.type == "number" then
            ---@cast input NumberInput
            if input:get_number() == nil then
                return field.def.title
            end
        end
    end
    return nil
end

---@private
---@param id string|nil `nil` asks about the whole kind
---@return boolean
function EntriesPanel:_may_write(id)
    local session = app.session
    return session ~= nil and session:is_allowed(permissions.Action.WRITE, self._kind, id)
end

---@private
---@return boolean
function EntriesPanel:_may_create()
    return entries.can_create(self._kind) and self:_may_write(nil)
end

---@private
---@param id string
---@return boolean
function EntriesPanel:_may_delete(id)
    return entries.can_delete(self._kind) and self:_may_write(id)
end

---@private
---@return boolean Whether the fields may be changed and applied: a new entry, or a selected one the player may write
function EntriesPanel:_is_editable()
    if self._is_new then
        return true
    end
    return self._selected ~= nil and self:_may_write(self._selected)
end

---@private
---@return EntriesPanelTexts|nil
function EntriesPanel:_get_texts()
    if not self._id_input then
        return nil
    end
    ---@type EntriesPanelTexts
    local texts = {
        id = self._id_input:get_text(),
        fields = {}
    }
    for _, field in ipairs(self._fields) do
        texts.fields[field.def.key] = field.input:get_text()
    end
    return texts
end

---@private
---@param texts EntriesPanelTexts|nil Restored into the rebuilt fields; `nil` fills them from the data
function EntriesPanel:_update_view(texts)
    local _, list_scroll = self._list_view:get_scroll()
    self:_release_controls()
    if self._selected and not entries.get(assert(app.data), self._kind, self._selected) then
        self._selected = nil
    end
    local list_bottom = self:_layout_list()
    self:_create_list_buttons()
    self._list_view:set_scroll(0, list_scroll)
    self:_disable_list_buttons_out_of_view()

    if not texts then
        self._fields_view:set_scroll(0, 0)
    end
    self:_create_fields(texts)
    local buttons_top = self:_create_buttons()
    local w = self:get_size()
    self._fields_view:set_position(0, list_bottom)
    self._fields_view:set_size(w, math.max(0, buttons_top - Consts.PADDING - list_bottom))
end

---@private
---@return number The bottom of the list's box and the padding below it
function EntriesPanel:_layout_list()
    local w, h = self:get_size()
    local p = Consts.PADDING
    local list_w, list_h = math.max(0, w - 2 * p), h * Consts.ENTRIES_PANEL_LIST_SHARE
    self._list_view:set_position(p, p)
    self._list_view:set_size(list_w, list_h)
    self._list_border:set_position(p, p)
    self._list_border:set_size(list_w, list_h)
    return p + list_h + p
end

---@private
function EntriesPanel:_create_list_buttons()
    local content = self._list_view:get_content()
    local s, half = Consts.PANEL_FIELD_SCALE, Consts.PADDING * 0.5
    local view_w = self._list_view:get_size()
    local content_w, y = view_w, half
    for _, id in ipairs(entries.list(assert(app.data), self._kind)) do
        local button = TextButton(content, self:get_game_screen(), id, function()
            self:select(id)
        end)
        button:set_scale(s)
        button:set_position(half, y)
        button:set_active(id == self._selected)
        local button_w, button_h = button:get_size()
        content_w = math.max(content_w, half + button_w * s + half)
        y = y + button_h * s + half
        table.insert(self._list_buttons, button)
    end
    self._list_view:set_content_size(content_w, y)
end

---@private
function EntriesPanel:_disable_list_buttons_out_of_view()
    local _, scroll = self._list_view:get_scroll()
    self._list_scroll = scroll
    local _, view_h = self._list_view:get_size()
    local s = Consts.PANEL_FIELD_SCALE
    for _, button in ipairs(self._list_buttons) do
        local _, y = button:get_position()
        local _, h = button:get_size()
        local top = y - scroll
        button:set_enabled(top + h * s > 0 and top < view_h)
    end
end

---@private
---@param caption string
---@param action InputHandler
---@return TextButton
function EntriesPanel:_create_button(caption, action)
    local button = TextButton(self, self:get_game_screen(), caption, action)
    button:set_scale(Consts.PANEL_FIELD_SCALE)
    return button
end

---@private
---@param button TextButton
---@param right boolean Along the right edge, the left one otherwise
---@param y number
function EntriesPanel:_place_button(button, right, y)
    local p = Consts.PADDING
    if right then
        local w = self:get_size()
        button:set_position(w - button:get_size() * Consts.PANEL_FIELD_SCALE - p, y)
    else
        button:set_position(p, y)
    end
end

---@private
---@return number The top of the buttons: of the New and Delete row for a kind that has one, of the Cancel and Apply row otherwise
function EntriesPanel:_create_buttons()
    local _, h = self:get_size()
    local s, p = Consts.PANEL_FIELD_SCALE, Consts.PADDING

    local cancel = self:_create_button("Cancel", function()
        self:cancel()
    end)
    self._cancel_button = cancel
    local _, cancel_h = cancel:get_size()
    local button_h = cancel_h * s
    local bottom_y = h - button_h - p
    self:_place_button(cancel, false, bottom_y)

    if self:_is_editable() then
        local apply = self:_create_button("Apply", function()
            self:apply()
        end)
        self._apply_button = apply
        self:_place_button(apply, true, bottom_y)
    end

    if not entries.can_create(self._kind) and not entries.can_delete(self._kind) then
        return bottom_y
    end
    local top_y = bottom_y - button_h - p * 0.5
    if self:_may_create() then
        local new = self:_create_button("New", function()
            self:start_new()
        end)
        self._new_button = new
        self:_place_button(new, false, top_y)
    end
    local selected = self._selected
    if selected and self:_may_delete(selected) then
        local delete = self:_create_button("Delete", function()
            self:delete()
        end)
        self._delete_button = delete
        self:_place_button(delete, true, top_y)
    end
    return top_y
end

---@private
---@param text string
---@return Text
function EntriesPanel:_create_field_title(text)
    local title = Text(self._fields_view:get_content(), text, Consts.FOREGROUND_COLOR)
    title:set_scale(Consts.PANEL_FIELD_SCALE)
    return title
end

---@private
---@param is_number boolean
---@return TextInput|NumberInput Applies on the return key
function EntriesPanel:_create_input(is_number)
    local content = self._fields_view:get_content()
    local w = self:get_size() - 2 * Consts.PADDING
    local apply = function()
        self:apply()
    end
    if is_number then
        return NumberInput(content, self:get_game_screen(), w, Consts.PANEL_TEXT_INPUT_HEIGHT, nil, apply)
    end
    return TextInput(content, self:get_game_screen(), w, Consts.PANEL_TEXT_INPUT_HEIGHT, false, nil, apply)
end

---@param input TextInput|NumberInput
---@param def EntryField
---@param value EntryValue|nil
local function _show_value(input, def, value)
    if def.type == "number" then
        ---@cast input NumberInput
        if type(value) == "number" then
            input:set_number(value)
        else
            input:set_text("")
        end
    elseif def.type == "grants" then
        input:set_text(type(value) == "table" and table.concat(value, " ") or "")
    else
        input:set_text(type(value) == "string" and value or "")
    end
end

---@private
---@param texts EntriesPanelTexts|nil
function EntriesPanel:_create_fields(texts)
    local w = self:get_size()
    local p = Consts.PADDING
    if not self._selected and not self._is_new then
        self._fields_view:set_content_size(w, 0)
        return
    end
    ---@type table<string, EntryValue|nil>
    local entry = self._selected and entries.get(assert(app.data), self._kind, self._selected) or {}
    local editable = self:_is_editable()

    local id_title = self:_create_field_title("Id")
    self._id_title = id_title
    id_title:set_position(p, p)
    local _, id_title_h = id_title:get_size()
    ---@type number
    local y = p + id_title_h * id_title:get_scale()
    local id_input = self:_create_input(false)
    self._id_input = id_input
    id_input:set_position(p, y)
    id_input:set_read_only(not (self._is_new or editable and entries.can_rename(self._kind)))
    id_input:set_text(texts and texts.id or self._selected or "")
    local _, id_input_h = id_input:get_size()
    y = y + id_input_h + p

    for _, def in ipairs(entries.FIELDS[self._kind]) do
        y = self:_create_field(def, y, entry[def.key], texts and texts.fields[def.key], editable)
    end
    self._fields_view:set_content_size(w, y)
end

---@private
---@param def EntryField
---@param y number The top of the field's title
---@param value EntryValue|nil The selected entry's
---@param kept string|nil The text to show instead of the value
---@param editable boolean
---@return number The bottom of the field and the padding below it
function EntriesPanel:_create_field(def, y, value, kept, editable)
    local p, s = Consts.PADDING, Consts.PANEL_FIELD_SCALE
    local title = self:_create_field_title(def.title)
    title:set_position(p, y)
    local _, title_h = title:get_size()
    local input_y = y + title_h * s

    local input = self:_create_input(def.type == "number")
    input:set_position(p, input_y)
    input:set_read_only(not editable or def.type == "image")
    if kept then
        input:set_text(kept)
    else
        _show_value(input, def, value)
    end
    local _, input_h = input:get_size()
    local bottom = input_y + input_h

    ---@type TextButton|nil
    local button
    if def.type == "image" then
        local key = def.key
        button = TextButton(self._fields_view:get_content(), self:get_game_screen(), editable and "Browse..." or "Show in assets...", function()
            self:_open_assets(key)
        end)
        button:set_scale(s)
        button:set_position(p, bottom + p * 0.5)
        local _, button_h = button:get_size()
        bottom = bottom + p * 0.5 + button_h * s
    end

    table.insert(self._fields, {
        def = def,
        title = title,
        input = input,
        button = button
    })
    return bottom + p
end

---@private
---@param key string An `image` field
function EntriesPanel:_open_assets(key)
    local path = assert(self:get_field_input(key)):get_text()
    ---@type AssetPick
    local pick = {
        path = path ~= "" and path or nil,
        media_type = media.Type.IMAGE,
        on_pick = nil
    }
    if self:_is_editable() then
        pick.on_pick = function(chosen)
            self:_set_image(key, chosen)
        end
    end
    assert(app.session):open_assets_workspace(pick)
end

---@private
---@param key string An `image` field
---@param path string
function EntriesPanel:_set_image(key, path)
    if not lifetime.alive(self) then
        return
    end
    local input = self:get_field_input(key)
    if input then
        input:set_text(path)
    end
end

---@private
function EntriesPanel:_release_controls()
    for _, button in ipairs(self._list_buttons) do
        lifetime.destroy(button)
    end
    self._list_buttons = {}

    for _, field in ipairs(self._fields) do
        lifetime.destroy(field.title)
        lifetime.destroy(field.input)
        if field.button then
            lifetime.destroy(field.button)
        end
    end
    self._fields = {}

    if self._id_title then
        lifetime.destroy(self._id_title)
        self._id_title = nil
    end
    if self._id_input then
        lifetime.destroy(self._id_input)
        self._id_input = nil
    end
    if self._cancel_button then
        lifetime.destroy(self._cancel_button)
        self._cancel_button = nil
    end
    if self._apply_button then
        lifetime.destroy(self._apply_button)
        self._apply_button = nil
    end
    if self._new_button then
        lifetime.destroy(self._new_button)
        self._new_button = nil
    end
    if self._delete_button then
        lifetime.destroy(self._delete_button)
        self._delete_button = nil
    end
end

return EntriesPanel

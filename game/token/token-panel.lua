local SidePanel = require("game.side-panel")
local Consts = require("app.consts")
local Text = require("controls.text")
local Image = require("controls.image")
local Avatar = require("game.token.avatar")
local TextInput = require("ui.text-input")
local NumberInput = require("ui.number-input")
local TextButton = require("ui.text-button")
local ScrollView = require("ui.scroll-view")
local lifetime = require("lifetime")
local media = require("utils.media")
local permissions = require("game.permissions")
local token_id = require("game.token.token-id")

---@class TokenPanelProperty
---@field key string Token data key
---@field def TokenProperty Property definition from `token_properties`
---@field title Text|nil Set once the property is filled in
---@field preview Image|Avatar|nil For an `image` property whose selected tokens agree on a file the store holds, between the title and the input: the avatar in its circle as on the page, another image fitted into a square, of `TOKEN_PANEL_IMAGE_PREVIEW_SIZE` either
---@field input TextInput|NumberInput|nil Set once the property is filled in, a `NumberInput` for a `number` property, read-only for an `image` property
---@field button TextButton|nil For an `image` property: opens the assets workspace at the asset, to browse for another or, read-only, to show it

---@class TokenPanel: SidePanel
---@field private _properties TokenPanelProperty[]
---@field private _keys string[]|nil Sorted editable keys of the selected tokens
---@field private _selection_set table<Token, boolean>
---@field private _cancel_button TextButton|nil
---@field private _new_button TextButton|nil Read-only without `write` on the tokens kind
---@field private _apply_button TextButton|nil Absent while the player may not write every selected token
---@field private _delete_button TextButton|nil Absent while nothing is selected or the player may not write every selected token
---@field private _scroll_view ScrollView Holds the properties, above the buttons
---@field private _id_title Text|nil Set while a token is selected
---@field private _id_input TextInput|nil Set while a token is selected; read-only and multivalue while several are
local TokenPanel = class("TokenPanel", SidePanel)

---@param game_screen GameScreen
---@param width number
---@param height number
function TokenPanel:init(game_screen, width, height)
    SidePanel.init(self, game_screen, width, height)
    self._properties = {}
    self._keys = nil
    self._selection_set = game_screen:get_selection():get_select_set()
    self._cancel_button = nil
    self._new_button = nil
    self._apply_button = nil
    self._delete_button = nil
    self._scroll_view = ScrollView(self, width, height, true)
    self._id_title = nil
    self._id_input = nil
end

---@param w number
---@param h number
function TokenPanel:on_resize(w, h)
    SidePanel.on_resize(self, w, h)
    self:_update_view()
end

function TokenPanel:on_selection_change()
    self._selection_set = self._game_screen:get_selection():get_select_set()
    self:_update_view()
end

---@param kind EntryKind
---@param id string
function TokenPanel:on_entries_change(kind, id)
    if kind == "token_properties" then
        self:_update_view()
    end
end

function TokenPanel:on_grants_change()
    self:_update_view()
end

---@private
function TokenPanel:_update_view()
    self:_release_properties()
    self:_update_property_keys()
    local is_writable = self:_is_selection_writable()
    self:_fill_in_properties(not is_writable)
    self:_create_buttons(is_writable)
    self:_layout_scroll_view()
end

---@private
function TokenPanel:_layout_scroll_view()
    local w = self:get_size()
    local _, button_y = assert(self._cancel_button):get_position()
    self._scroll_view:set_position(0, 0)
    self._scroll_view:set_size(w, math.max(0, button_y - Consts.PADDING))
end

---@private
---@return boolean
function TokenPanel:_is_selection_writable()
    for token in pairs(self._selection_set) do
        if not token:is_writable() then
            return false
        end
    end
    return true
end

---@private
---@return Token|nil The selected token when exactly one is
function TokenPanel:_get_single_token()
    local token = next(self._selection_set)
    if token == nil or next(self._selection_set, token) ~= nil then
        return nil
    end
    return token
end

---@private
function TokenPanel:_update_property_keys()
    ---@type table<string, boolean>
    local unique_keys = {}
    for token in pairs(self._selection_set) do
        ---@type table<string, TokenDataValue>
        local data = token:get_data()
        for k in pairs(data) do
            unique_keys[k] = true
        end
    end
    ---@type string[]
    local keys = {}
    for k in pairs(unique_keys) do
        local def = app.data.token_properties[k]
        local t = def and def.type
        if t == "string" or t == "number" or t == "image" then
            table.insert(keys, k)
        end
    end
    table.sort(keys)
    self._keys = keys
end

---@private
---@param read_only boolean
function TokenPanel:_fill_in_properties(read_only)
    local y = self:_create_id_field(read_only)
    for _, k in ipairs(self._keys) do
        if app.data.token_properties[k] then
            ---@type TokenPanelProperty
            local property = {
                key = k,
                def = app.data.token_properties[k],
                title = nil,
                preview = nil,
                input = nil,
                button = nil
            }

            do
                local title = self:_create_field_title(property.def.title)
                property.title = title
                title:set_position(Consts.PADDING, y)
                local _, h = title:get_size()
                y = y + h * title:get_scale()
            end

            local t = property.def.type
            if t == "image" then
                local preview = self:_create_image_preview(k)
                if preview then
                    property.preview = preview
                    preview:set_position(Consts.PADDING, y)
                    ---@type number
                    y = y + Consts.TOKEN_PANEL_IMAGE_PREVIEW_SIZE + Consts.PADDING * 0.5
                end
            end

            do
                local input = self:_create_property_input(property)
                property.input = input
                input:set_read_only(read_only or t == "image")
                input:set_position(Consts.PADDING, y)
                local _, h = input:get_size()
                ---@type number
                y = y + h

                local is_single_value, value = self:_get_value_by_key(k)
                if is_single_value then
                    if t == "string" or t == "image" then
                        ---@cast value string
                        input:set_text(value)
                    elseif t == "number" then
                        ---@cast input NumberInput
                        ---@cast value number
                        input:set_number(value)
                    end
                else
                    input:set_multivalue(true)
                end
            end

            if t == "image" then
                local button = self:_create_assets_button(property, read_only and "Show in assets..." or "Browse...")
                property.button = button
                button:set_position(Consts.PADDING, y + Consts.PADDING * 0.5)
                local _, h = button:get_size()
                y = y + Consts.PADDING * 0.5 + h * Consts.PANEL_FIELD_SCALE
            end

            table.insert(self._properties, property)

            y = y + Consts.PADDING
        end
    end
    local w = self:get_size()
    self._scroll_view:set_content_size(w, y)
end

---@private
---@param read_only boolean
---@return number The height of the field and the padding below it; `0` with no token selected
function TokenPanel:_create_id_field(read_only)
    if next(self._selection_set) == nil then
        return 0
    end
    local title = self:_create_field_title("Id")
    self._id_title = title
    title:set_position(Consts.PADDING, Consts.PADDING)
    local _, title_h = title:get_size()
    local y = Consts.PADDING + title_h * title:get_scale()

    local panel_w = self:get_size()
    local input = TextInput(self._scroll_view:get_content(), self._game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, false, nil, function()
        self:_apply()
    end)
    self._id_input = input
    input:set_position(Consts.PADDING, y)
    local token = self:_get_single_token()
    if token then
        input:set_read_only(read_only)
        input:set_text(token:get_id())
    else
        input:set_read_only(true)
        input:set_multivalue(true)
    end
    local _, input_h = input:get_size()
    return y + input_h + Consts.PADDING
end

---@private
---@param text string
---@return Text
function TokenPanel:_create_field_title(text)
    local title = Text(self._scroll_view:get_content(), text, Consts.FOREGROUND_COLOR)
    title:set_scale(Consts.PANEL_FIELD_SCALE)
    return title
end

---@private
---@param key string An `image` property
---@return Image|Avatar|nil Absent unless the selected tokens agree on a file of the joined game's store
function TokenPanel:_create_image_preview(key)
    local is_single_value, path = self:_get_value_by_key(key)
    local store = app.asset_manager:get_store()
    if not is_single_value or type(path) ~= "string" or not store or store:asset(path):get_type() ~= "file" then
        return nil
    end
    local content = self._scroll_view:get_content()
    local size = Consts.TOKEN_PANEL_IMAGE_PREVIEW_SIZE
    if key == "avatar" then
        return Avatar(content, path, size)
    end
    local image = Image(content, path)
    local w, h = image:get_size()
    image:set_scale(math.min(size / w, size / h))
    return image
end

---@private
---@param property TokenPanelProperty
---@return TextInput|NumberInput
function TokenPanel:_create_property_input(property)
    local panel_w = self:get_size()
    local content = self._scroll_view:get_content()

    local t = property.def.type
    local apply = function()
        self:_apply()
    end

    ---@type TextInput|NumberInput
    local input
    if t == "string" then
        input = TextInput(content, self._game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, false, nil, apply)
    elseif t == "number" then
        input = NumberInput(content, self._game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, nil, apply)
    elseif t == "image" then
        input = TextInput(content, self._game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    else
        assert_unreachable()
    end
    return input
end

---@private
---@param property TokenPanelProperty
---@param caption string
---@return TextButton
function TokenPanel:_create_assets_button(property, caption)
    local button = TextButton(self._scroll_view:get_content(), self._game_screen, caption, function()
        self:_open_assets(property.key)
    end)
    button:set_scale(Consts.PANEL_FIELD_SCALE)
    return button
end

---@private
---@param key string An `image` property
function TokenPanel:_open_assets(key)
    local is_single_value, value = self:_get_value_by_key(key)
    ---@type AssetPick
    local pick = {
        path = is_single_value and type(value) == "string" and value or nil,
        media_type = media.Type.IMAGE,
        on_pick = nil
    }
    if self:_is_selection_writable() then
        pick.on_pick = function(path)
            self:_set_image(key, path)
        end
    end
    assert(app.session):open_assets_workspace(pick)
end

---@private
---@param key string An `image` property
---@param path string
function TokenPanel:_set_image(key, path)
    local session = assert(app.session)
    for token in pairs(self._selection_set) do
        if token:get_data()[key] ~= path then
            token:set_data(key, path)
            session:update_token(token:get_id(), {
                [key] = path
            })
        end
    end
    self:_update_view()
end

---@private
---@param key string
---@return boolean is_single_value
---@return TokenDataValue|nil value Common value when all selected tokens agree
function TokenPanel:_get_value_by_key(key)
    local once = true
    ---@type TokenDataValue|nil
    local value
    for token in pairs(self._selection_set) do
        local current = token:get_data()[key]
        if once then
            once = false
            value = current
        elseif value ~= current then
            return false, nil
        end
    end
    return true, value
end

---@private
---@param caption string
---@param action InputHandler
---@return TextButton
function TokenPanel:_create_button(caption, action)
    local button = TextButton(self, self._game_screen, caption, action)
    button:set_scale(Consts.PANEL_FIELD_SCALE)
    return button
end

---@private
---@param is_writable boolean Whether the player may write every selected token: Apply, and Delete for a selection that is not empty
function TokenPanel:_create_buttons(is_writable)
    local cancel = self:_create_button("Cancel", function()
        self:cancel()
    end)
    self._cancel_button = cancel

    local new = self:_create_button("New", function()
        assert(app.session):show_new_token()
    end)
    self._new_button = new
    local session = app.session
    new:set_read_only(not (session and session:is_allowed(permissions.Action.WRITE, permissions.Kind.TOKENS)))

    local y = self:_get_button_y(cancel)
    local s, p = Consts.PANEL_FIELD_SCALE, Consts.PADDING
    cancel:set_position(p, y)
    local new_x = p + cancel:get_size() * s + p
    new:set_position(new_x, y)

    if not is_writable then
        return
    end
    ---@type TextButton|nil
    local delete
    if next(self._selection_set) ~= nil then
        delete = self:_create_button("Delete", function()
            self:_delete()
        end)
        self._delete_button = delete
    end
    local apply = self:_create_button("Apply", function()
        self:_apply()
    end)
    self._apply_button = apply
    local w = self:get_size()
    local apply_x = w - apply:get_size() * s - p
    apply:set_position(apply_x, y)
    if delete then
        local new_end = new_x + new:get_size() * s
        delete:set_position((new_end + apply_x - delete:get_size() * s) * 0.5, y)
    end
end

---@private
---@param button TextButton Scaled by `PANEL_FIELD_SCALE`
---@return number The top of the bottom row, a padding above the panel's bottom
function TokenPanel:_get_button_y(button)
    local _, h = self:get_size()
    local _, button_h = button:get_size()
    return h - button_h * Consts.PANEL_FIELD_SCALE - Consts.PADDING
end

---@private
function TokenPanel:_delete()
    ---@type string[]
    local ids = {}
    for token in pairs(self._selection_set) do
        table.insert(ids, token:get_id())
    end
    table.sort(ids)
    local session = assert(app.session)
    for _, id in ipairs(ids) do
        session:delete_token(id)
    end
end

---@private
function TokenPanel:_release_properties()
    for _, v in ipairs(self._properties) do
        lifetime.destroy(v.title)
        if v.preview then
            lifetime.destroy(v.preview)
        end
        lifetime.destroy(v.input)
        if v.button then
            lifetime.destroy(v.button)
        end
    end
    self._properties = {}

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

    if self._new_button then
        lifetime.destroy(self._new_button)
        self._new_button = nil
    end

    if self._apply_button then
        lifetime.destroy(self._apply_button)
        self._apply_button = nil
    end

    if self._delete_button then
        lifetime.destroy(self._delete_button)
        self._delete_button = nil
    end
end

---@private
---@return string|nil The id the single selected token had, when the field renamed it
function TokenPanel:_apply_id()
    local token, input = self:_get_single_token(), self._id_input
    if not token or not input or input:is_read_only() then
        return nil
    end
    local id = input:get_text()
    local old = token:get_id()
    if id == old then
        return nil
    end
    local reason = token_id.check(assert(app.data), id)
    if reason then
        app.notification_manager:notify(reason)
        return nil
    end
    token:set_id(id)
    return old
end

---@private
---@param changes table<Token, table<string, TokenDataValue>> The changes made, by token; a `nil` the wire cannot carry is applied but not recorded
---@param key string
---@param value TokenDataValue|nil
function TokenPanel:_apply_value(changes, key, value)
    for token in pairs(self._selection_set) do
        if token:get_data()[key] ~= value then
            token:set_data(key, value)
            if value ~= nil then
                local token_changes = changes[token] or {}
                token_changes[key] = value
                changes[token] = token_changes
            end
        end
    end
end

---@private
---@return string|nil The title of the first number property whose field holds no number, which refuses the whole apply
function TokenPanel:_find_missing_number()
    for _, property in ipairs(self._properties) do
        local input = property.input
        if property.def.type == "number" and input and not input:is_multivalue_default() then
            ---@cast input NumberInput
            if input:get_number() == nil then
                return property.def.title
            end
        end
    end
    return nil
end

---@private
function TokenPanel:_apply()
    local missing_number = self:_find_missing_number()
    if missing_number then
        app.notification_manager:notify(missing_number .. " needs a number")
        return
    end
    local renamed_from = self:_apply_id()
    ---@type table<Token, table<string, TokenDataValue>>
    local changes = {}
    for _, property in ipairs(self._properties) do
        if not property.input:is_multivalue_default() then
            local t = property.def.type
            if t == "string" then
                self:_apply_value(changes, property.key, property.input:get_text())
            elseif t == "number" then
                local input = property.input
                ---@cast input NumberInput
                self:_apply_value(changes, property.key, input:get_number())
            elseif t ~= "image" then
                assert_unreachable()
            end
        end
    end
    local session = assert(app.session)
    for token in pairs(self._selection_set) do
        if renamed_from and token == self:_get_single_token() then
            session:update_token(renamed_from, changes[token] or {}, token:get_id())
        elseif changes[token] then
            session:update_token(token:get_id(), changes[token])
        end
    end
end

function TokenPanel:cancel()
    self._game_screen:get_selection():unselect()
end

return TokenPanel

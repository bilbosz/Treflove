local Consts = require("app.consts")
local Panel = require("ui.panel")
local PreviewArea = require("game.assets.preview-area.preview-area")
local ScrollView = require("ui.scroll-view")
local Text = require("controls.text")
local TextButton = require("ui.text-button")
local TextInput = require("ui.text-input")
local media = require("utils.media")

---@alias AssetDetailsAction "upload"|"new_folder"|"rename"|"delete"|"use" The buttons the workspace enables by its state; `use` only when it picks a file

---@class AssetDetails: Panel, FileDropTarget
---@field _screen AssetsWorkspaceScreen
---@field _preview_area PreviewArea
---@field _name_input TextInput
---@field _type_input TextInput
---@field _action_buttons table<AssetDetailsAction, TextButton>
---@field _back_button TextButton
---@field _scroll_view ScrollView Holds the preview and the fields, above the buttons
local AssetDetails = class("AssetDetails", Panel)

---@param self AssetDetails
---@param label string
---@param y number
---@return TextInput input
---@return number bottom The y below the field
local function _create_field(self, label, y)
    local w = self:get_size()
    local content = self._scroll_view:get_content()
    local text = Text(content, label, Consts.FOREGROUND_COLOR)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    text:set_position(Consts.PADDING, y)
    local _, text_h = text:get_outer_size()

    local input = TextInput(content, self._screen, w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, false, function()
        self._screen:on_name_edited()
    end)
    input:set_position(Consts.PADDING, y + text_h + Consts.PADDING * 0.5)
    local _, input_h = input:get_size()
    return input, y + text_h + Consts.PADDING * 0.5 + input_h + Consts.PADDING
end

---@param self AssetDetails
---@param caption string
---@param action AssetDetailsAction
---@return TextButton
local function _create_action_button(self, caption, action)
    local button = TextButton(self, self._screen, caption, function()
        self._screen:run_action(action)
    end)
    button:set_scale(Consts.PANEL_FIELD_SCALE)
    self._action_buttons[action] = button
    return button
end

---@param self AssetDetails
---@return number top The y of the topmost button
local function _layout_buttons(self)
    local w, h = self:get_size()
    local s = Consts.PANEL_FIELD_SCALE
    ---@param button TextButton
    ---@return number, number
    local function outer_size(button)
        local bw, bh = button:get_size()
        return bw * s, bh * s
    end

    local back_w, back_h = outer_size(self._back_button)
    local bottom_y = h - Consts.PADDING - back_h
    self._back_button:set_position(Consts.PADDING, bottom_y)
    local use = self._action_buttons.use
    if use then
        use:set_position(Consts.PADDING + back_w + Consts.PADDING, bottom_y)
    end
    local upload = self._action_buttons.upload
    local upload_w = outer_size(upload)
    upload:set_position(w - Consts.PADDING - upload_w, bottom_y)

    local x = Consts.PADDING
    local row_y = bottom_y - Consts.PADDING - back_h
    ---@type AssetDetailsAction[]
    local order = {
        "new_folder",
        "rename",
        "delete"
    }
    for _, action in ipairs(order) do
        local button = self._action_buttons[action]
        local bw = outer_size(button)
        button:set_position(x, row_y)
        x = x + bw + Consts.PADDING
    end
    return row_y
end

---@param self AssetDetails
local function _layout(self)
    local w = self:get_size()
    local top = _layout_buttons(self)
    self._scroll_view:set_position(0, 0)
    self._scroll_view:set_size(w, math.max(0, top - Consts.PADDING))
end

---@param screen AssetsWorkspaceScreen
---@param parent Control
---@param width number
---@param height number
---@param with_use boolean Whether the workspace picks a file: a Use button
function AssetDetails:init(screen, parent, width, height, with_use)
    Panel.init(self, parent, width, height)
    self._screen = screen
    self._action_buttons = {}
    self._scroll_view = ScrollView(self, width, height, true)

    local side = math.min(width - 2 * Consts.PADDING, height * Consts.ASSETS_WORKSPACE_PREVIEW_SHARE)
    local preview = PreviewArea(self._scroll_view:get_content(), side, side, self)
    self._preview_area = preview
    preview:set_position(Consts.PADDING, Consts.PADDING)

    local y = Consts.PADDING + side + Consts.PADDING
    self._name_input, y = _create_field(self, "Name", y)
    self._type_input, y = _create_field(self, "Type", y)
    self._type_input:set_read_only(true)
    self._scroll_view:set_content_size(width, y)

    _create_action_button(self, "New Folder", "new_folder")
    _create_action_button(self, "Rename", "rename")
    _create_action_button(self, "Delete", "delete")
    _create_action_button(self, "Upload", "upload")
    if with_use then
        _create_action_button(self, "Use", "use")
    end
    local back = TextButton(self, screen, "Back", function()
        app.backstack_manager:back()
    end)
    back:set_scale(Consts.PANEL_FIELD_SCALE)
    self._back_button = back
    _layout(self)
end

---@param file love.DroppedFile
function AssetDetails:set_file(file)
    self._screen:take_dropped_file(file)
end

---@return string
function AssetDetails:get_name()
    return self._name_input:get_text()
end

---@param name string
function AssetDetails:set_name(name)
    self._name_input:set_text(name)
end

---@param value boolean
function AssetDetails:set_name_editable(value)
    self._name_input:set_read_only(not value)
end

---@param text string
function AssetDetails:set_type_text(text)
    self._type_input:set_text(text)
end

---@param media_type media.Type|nil
---@param medium LoveMedium
function AssetDetails:show_medium(media_type, medium)
    self._preview_area:show_medium(media_type, medium)
    self:set_type_text(media_type and tostring(table.find_table_key(media.Type, media_type)) or "Unknown")
end

function AssetDetails:clear_preview()
    self._preview_area:reset()
end

---@param enabled table<AssetDetailsAction, boolean> The actions the state allows; the others are read-only
function AssetDetails:set_actions(enabled)
    for action, button in pairs(self._action_buttons) do
        button:set_read_only(not enabled[action])
    end
end

---@param action AssetDetailsAction
---@return TextButton|nil Absent for `use` unless the workspace picks a file
function AssetDetails:get_action_button(action)
    return self._action_buttons[action]
end

---@param w number
---@param h number
function AssetDetails:on_resize(w, h)
    Panel.on_resize(self, w, h)
    _layout(self)
end

return AssetDetails

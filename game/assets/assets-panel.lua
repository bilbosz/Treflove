local Panel = require("ui.panel")
local PreviewArea = require("game.assets.preview-area.preview-area")
local PreviewAudioArea = require("game.assets.preview-area.preview-audio-area")
local PreviewImageArea = require("game.assets.preview-area.preview-image-area")
local Consts = require("app.consts")
local Text = require("controls.text")
local TextInput = require("ui.text-input")
local TextButton = require("ui.text-button")
local Utils = require("utils.utils")

local media = require("utils.media")

---@class AssetsPanel: Panel
---@field _game_screen GameScreen
---@field _location_input TextInput
---@field _remote_location_input TextInput
---@field _preview_area PreviewArea
---@field _file_type_input TextInput
---@field _upload_button TextButton
---@field _cancel_button TextButton
---@field _media_type Media.Type|nil
---@field _data string|nil Raw content of the dropped file
---@field _data_size number|nil
local AssetsPanel = class("AssetsPanel", Panel)

-- Preview component class tables by media type. The values are class tables
-- (constructors), which LuaLS cannot type against the instance union — hence
-- `any`; the instance contract is documented on PreviewArea:set_content.
---@type table<Media.Type, any>
local FILE_TYPE_PREVIEW = {
    [media.Type.IMAGE] = PreviewImageArea,
    [media.Type.AUDIO] = PreviewAudioArea,
    [media.Type.VIDEO] = nil,
    [media.Type.TEXT] = nil,
    [media.Type.FONT] = nil
}

---@param self AssetsPanel
local function _create_preview_area(self)
    local w = self:get_size() - 2 * Consts.PADDING
    self._preview_area = PreviewArea(self, w, w)
    self._preview_area:set_position(Consts.PADDING, Consts.PADDING)
end

---@param self AssetsPanel
---@return Text
local function _create_location_label(self)
    local text = Text(self, "Local path", Consts.FOREGROUND_COLOR)
    local _, area_y, _, area_h = self._preview_area:get_position_and_size()

    text:set_position(Consts.PADDING, area_y + area_h + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

---@param self AssetsPanel
---@return TextInput
local function _create_location_input(self)
    local panel_w = self:get_size()
    local input = TextInput(self, self._game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self._location_input = input

    input:set_read_only(true)
    return input
end

---@param self AssetsPanel
local function _create_location_field(self)
    local text = _create_location_label(self)
    local text_x, text_y, _, text_h = text:get_position_and_outer_size()

    local input = _create_location_input(self)
    input:set_position(text_x, text_y + text_h + Consts.PADDING)
end

---@param self AssetsPanel
---@return Text
local function _create_file_type_label(self)
    local text = Text(self, "File type", Consts.FOREGROUND_COLOR)
    local _, input_y, _, input_h = self._location_input:get_position_and_size()

    text:set_position(Consts.PADDING, input_y + input_h + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

---@param self AssetsPanel
---@return TextInput
local function _create_file_type_input(self)
    local panel_w = self:get_size()
    local input = TextInput(self, self._game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self._file_type_input = input

    input:set_read_only(true)
    return input
end

---@param self AssetsPanel
local function _create_file_type_field(self)
    local text = _create_file_type_label(self)
    local text_x, text_y, _, text_h = text:get_position_and_outer_size()
    local input = _create_file_type_input(self)
    input:set_position(text_x, text_y + text_h + Consts.PADDING)
end

---@param self AssetsPanel
---@return Text
local function _create_remote_location_label(self)
    local text = Text(self, "Remote location", Consts.FOREGROUND_COLOR)
    local _, input_y, _, input_h = self._file_type_input:get_position_and_size()

    text:set_position(Consts.PADDING, input_y + input_h + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

---@param self AssetsPanel
---@return TextInput
local function _create_remote_location_input(self)
    local panel_w = self:get_size()
    local input = TextInput(self, self._game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self._remote_location_input = input

    input:set_read_only(true)
    return input
end

---@param self AssetsPanel
local function _create_remote_location_field(self)
    local text = _create_remote_location_label(self)
    local text_x, text_y, _, text_h = text:get_position_and_outer_size()
    local input = _create_remote_location_input(self)
    input:set_position(text_x, text_y + text_h + Consts.PADDING)
end

---@param self AssetsPanel
local function _refresh_upload_button_geometry(self)
    local w, h = self:get_size()
    local button = self._upload_button
    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local button_w, button_h = button:get_size()
    button:set_position(w - button_w * s - Consts.PADDING, h - button_h * s - Consts.PADDING)
end

---@param self AssetsPanel
local function _refresh_cancel_button_geometry(self)
    local _, h = self:get_size()
    local button = self._cancel_button
    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local button_h = select(2, button:get_size())
    button:set_position(Consts.PADDING, h - button_h * s - Consts.PADDING)
end

---@param self AssetsPanel
local function _create_upload_button(self)
    local button = TextButton(self, self._game_screen, "Upload", function()
        self:_upload()
    end)
    self._upload_button = button

    _refresh_upload_button_geometry(self)
end

---@param self AssetsPanel
local function _create_cancel_button(self)
    local button = TextButton(self, self._game_screen, "Cancel", function()
        self:cancel()
    end)
    self._cancel_button = button

    _refresh_cancel_button_geometry(self)
end

---@param self AssetsPanel
local function _refresh_action_buttons(self)
    _refresh_upload_button_geometry(self)
    _refresh_cancel_button_geometry(self)
end

---@param self AssetsPanel
---@param data string Raw file content
local function _set_file_type(self, data)
    local media_type, medium = media.get_type_and_medium(data)
    self._media_type = media_type
    local FileTypePreview = FILE_TYPE_PREVIEW[media_type]
    if FileTypePreview then
        self._preview_area:set_content(medium, FileTypePreview)
    end
    self._file_type_input:set_text(tostring(table.find_table_key(media.Type, media_type)))
end

---@param game_screen GameScreen
---@param width number
---@param height number
function AssetsPanel:init(game_screen, width, height)
    Panel.init(self, game_screen:get_control(), width, height)
    self._game_screen = game_screen
    self._media_type = nil
    self._data = nil
    self._data_size = nil
    _create_preview_area(self)
    _create_location_field(self)
    _create_file_type_field(self)
    _create_remote_location_field(self)
    _create_cancel_button(self)
    _create_upload_button(self)
end

---@param file love.DroppedFile
function AssetsPanel:set_file(file)
    local data = file:read("data") --[[@as string]]
    local size = file:getSize()
    self._data = data
    self._data_size = size
    _set_file_type(self, data)

    local path = file:getFilename()
    self._location_input:set_text(path)
    local split_path = Utils.split_path(path)

    local file_name = split_path[#split_path]
    self._remote_location_input:set_text(file_name)
    self._remote_location_input:set_read_only(false)
end

---@param w number
---@param h number
function AssetsPanel:on_resize(w, h)
    Panel.on_resize(self, w, h)
    _refresh_action_buttons(self)
end

function AssetsPanel:reset()
    self._preview_area:reset()
    self._location_input:set_text("")
    self._file_type_input:set_text("")
    self._remote_location_input:set_read_only(true)
    self._remote_location_input:set_text("")
    self._media_type = nil
    self._data = nil
    self._data_size = nil
end

function AssetsPanel:_upload()
    if self._data then
        app.asset_manager:upload_asset(self._remote_location_input:get_text(), self._data)
    end
end

function AssetsPanel:cancel()
    self:reset()
end

function AssetsPanel:release()
    self._preview_area:release()
end

return AssetsPanel

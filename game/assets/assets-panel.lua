local Panel = require("ui.panel")
local PreviewArea = require("game.assets.preview-area.preview-area")
local PreviewAudioArea = require("game.assets.preview-area.preview-audio-area")
local PreviewImageArea = require("game.assets.preview-area.preview-image-area")
local Media = require("utils.media")
local Consts = require("app.consts")
local Text = require("controls.text")
local TextInput = require("ui.text-input")
local TextButton = require("ui.text-button")
local Utils = require("utils.utils")

---@class AssetsPanel: Panel
local AssetsPanel = class("AssetsPanel", Panel)

local FILE_TYPE_PREVIEW = {
    [Media.Type.IMAGE] = PreviewImageArea,
    [Media.Type.AUDIO] = PreviewAudioArea,
    [Media.Type.VIDEO] = nil,
    [Media.Type.TEXT] = nil,
    [Media.Type.FONT] = nil
}

local function _create_preview_area(self)
    local w = self:get_size() - 2 * Consts.PADDING
    self.preview_area = PreviewArea(self, w, w)
    self.preview_area:set_position(Consts.PADDING, Consts.PADDING)
end

local function _create_location_label(self)
    local text = Text(self, "Local path", Consts.FOREGROUND_COLOR)
    local _, area_y, _, area_h = self.preview_area:get_position_and_size()

    text:set_position(Consts.PADDING, area_y + area_h + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function _create_location_input(self)
    local panel_w = self:get_size()
    local input = TextInput(self, self.game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.location_input = input

    input:set_read_only(true)
    return input
end

local function _create_location_field(self)
    local text = _create_location_label(self)
    local text_x, text_y, _, text_h = text:get_position_and_outer_size()

    local input = _create_location_input(self)
    input:set_position(text_x, text_y + text_h + Consts.PADDING)
end

local function _create_file_type_label(self)
    local text = Text(self, "File type", Consts.FOREGROUND_COLOR)
    local _, input_y, _, input_h = self.location_input:get_position_and_size()

    text:set_position(Consts.PADDING, input_y + input_h + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function _create_file_type_input(self)
    local panel_w = self:get_size()
    local input = TextInput(self, self.game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.file_type_input = input

    input:set_read_only(true)
    return input
end

local function _create_file_type_field(self)
    local text = _create_file_type_label(self)
    local text_x, text_y, _, text_h = text:get_position_and_outer_size()
    local input = _create_file_type_input(self)
    input:set_position(text_x, text_y + text_h + Consts.PADDING)
end

local function _create_remote_location_label(self)
    local text = Text(self, "Remote location", Consts.FOREGROUND_COLOR)
    local _, input_y, _, input_h = self.file_type_input:get_position_and_size()

    text:set_position(Consts.PADDING, input_y + input_h + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function _create_remote_location_input(self)
    local panel_w = self:get_size()
    local input = TextInput(self, self.game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.remote_location_input = input

    input:set_read_only(true)
    return input
end

local function _create_remote_location_field(self)
    local text = _create_remote_location_label(self)
    local text_x, text_y, _, text_h = text:get_position_and_outer_size()
    local input = _create_remote_location_input(self)
    input:set_position(text_x, text_y + text_h + Consts.PADDING)
end

local function _refresh_upload_button_geometry(self)
    local w, h = self:get_size()
    local button = self.upload_button
    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local button_w, button_h = button:get_size()
    button:set_position(w - button_w * s - Consts.PADDING, h - button_h * s - Consts.PADDING)
end

local function _refresh_cancel_button_geometry(self)
    local _, h = self:get_size()
    local button = self.cancel_button
    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local button_h = select(2, button:get_size())
    button:set_position(Consts.PADDING, h - button_h * s - Consts.PADDING)
end

local function _create_upload_button(self)
    local button = TextButton(self, self.game_screen, "Upload", function()
        self:_upload()
    end)
    self.upload_button = button

    _refresh_upload_button_geometry(self)
end

local function _create_cancel_button(self)
    local h = select(2, self:get_size())

    local button = TextButton(self, self.game_screen, "Cancel", function()
        self:cancel()
    end)
    self.cancel_button = button

    _refresh_cancel_button_geometry(self)
end

local function _refresh_action_buttons(self)
    _refresh_upload_button_geometry(self)
    _refresh_cancel_button_geometry(self)
end

local function _set_file_type(self, data)
    local media_type, medium = Media.GetTypeAndMedium(data)
    self.media_type = media_type
    local file_type_preview = FILE_TYPE_PREVIEW[media_type]
    if file_type_preview then
        self.preview_area:SetContent(medium, file_type_preview)
    end
    self.file_type_input:set_text(tostring(table.find_table_key(Media.Type, media_type)))
end

function AssetsPanel:init(game_screen, width, height)
    Panel.init(self, game_screen:get_control(), width, height)
    self.game_screen = game_screen
    self.media_type = nil
    self.data = nil
    self.data_size = nil
    _create_preview_area(self)
    _create_location_field(self)
    _create_file_type_field(self)
    _create_remote_location_field(self)
    _create_cancel_button(self)
    _create_upload_button(self)
end

function AssetsPanel:set_file(file)
    local data = file:read("data")
    local size = file:getSize()
    self.data = data
    self.data_size = size
    _set_file_type(self, data)

    local path = file:getFilename()
    self.location_input:set_text(path)
    local split_path = Utils.split_path(path)

    local file_name = split_path[#split_path]
    self.remote_location_input:set_text(file_name)
    self.remote_location_input:set_read_only(false)
end

function AssetsPanel:on_resize(w, h)
    Panel.on_resize(self, w, h)
    _refresh_action_buttons(self)
end

function AssetsPanel:reset()
    self.preview_area:reset()
    self.location_input:set_text("")
    self.file_type_input:set_text("")
    self.remote_location_input:set_read_only(true)
    self.remote_location_input:set_text("")
    self.media_type = nil
    self.data = nil
    self.data_size = nil
end

function AssetsPanel:_upload()
    app.asset_manager:upload_asset(self.remote_location_input:get_text(), self.data)
end

function AssetsPanel:cancel()
    self:reset()
end

function AssetsPanel:release()
    self.preview_area:release()
end

return AssetsPanel

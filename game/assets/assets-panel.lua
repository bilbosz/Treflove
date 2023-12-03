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

local function CreatePreviewArea(self)
    local w = self:get_size() - 2 * Consts.PADDING
    self.preview_area = PreviewArea(self, w, w)
    self.preview_area:set_position(Consts.PADDING, Consts.PADDING)
end

local function CreateLocationLabel(self)
    local text = Text(self, "Local path", Consts.FOREGROUND_COLOR)
    local _, area_y, _, area_h = self.preview_area:get_position_and_size()

    text:set_position(Consts.PADDING, area_y + area_h + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateLocationInput(self)
    local panel_w = self:get_size()
    local input = TextInput(self, self.game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.location_input = input

    input:set_read_only(true)
    return input
end

local function CreateLocationField(self)
    local text = CreateLocationLabel(self)
    local text_x, text_y, _, text_h = text:get_position_and_outer_size()

    local input = CreateLocationInput(self)
    input:set_position(text_x, text_y + text_h + Consts.PADDING)
end

local function CreateFileTypeLabel(self)
    local text = Text(self, "File type", Consts.FOREGROUND_COLOR)
    local _, input_y, _, input_h = self.location_input:get_position_and_size()

    text:set_position(Consts.PADDING, input_y + input_h + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateFileTypeInput(self)
    local panel_w = self:get_size()
    local input = TextInput(self, self.game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.fileTypeInput = input

    input:set_read_only(true)
    return input
end

local function CreateFileTypeField(self)
    local text = CreateFileTypeLabel(self)
    local text_x, text_y, _, text_h = text:get_position_and_outer_size()
    local input = CreateFileTypeInput(self)
    input:set_position(text_x, text_y + text_h + Consts.PADDING)
end

local function CreateRemoteLocationLabel(self)
    local text = Text(self, "Remote location", Consts.FOREGROUND_COLOR)
    local _, input_y, _, input_h = self.fileTypeInput:get_position_and_size()

    text:set_position(Consts.PADDING, input_y + input_h + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateRemoteLocationInput(self)
    local panel_w = self:get_size()
    local input = TextInput(self, self.game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.remoteLocationInput = input

    input:set_read_only(true)
    return input
end

local function CreateRemoteLocationField(self)
    local text = CreateRemoteLocationLabel(self)
    local text_x, text_y, _, text_h = text:get_position_and_outer_size()
    local input = CreateRemoteLocationInput(self)
    input:set_position(text_x, text_y + text_h + Consts.PADDING)
end

local function RefreshUploadButtonGeometry(self)
    local w, h = self:get_size()
    local button = self.upload_button
    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local button_w, button_h = button:get_size()
    button:set_position(w - button_w * s - Consts.PADDING, h - button_h * s - Consts.PADDING)
end

local function RefreshCancelButtonGeometry(self)
    local _, h = self:get_size()
    local button = self.cancel_button
    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local button_h = select(2, button:get_size())
    button:set_position(Consts.PADDING, h - button_h * s - Consts.PADDING)
end

local function CreateUploadButton(self)
    local button = TextButton(self, self.game_screen, "Upload", function()
        self:_upload()
    end)
    self.upload_button = button

    RefreshUploadButtonGeometry(self)
end

local function _create_cancel_button(self)
    local h = select(2, self:get_size())

    local button = TextButton(self, self.game_screen, "Cancel", function()
        self:cancel()
    end)
    self.cancel_button = button

    RefreshCancelButtonGeometry(self)
end

local function RefreshActionButtons(self)
    RefreshUploadButtonGeometry(self)
    RefreshCancelButtonGeometry(self)
end

local function SetFileType(self, data)
    local media_type, medium = Media.GetTypeAndMedium(data)
    self.media_type = media_type
    local fileTypePreview = FILE_TYPE_PREVIEW[media_type]
    if fileTypePreview then
        self.preview_area:SetContent(medium, fileTypePreview)
    end
    self.fileTypeInput:set_text(tostring(table.find_table_key(Media.Type, media_type)))
end

function AssetsPanel:init(game_screen, width, height)
    Panel.init(self, game_screen:get_control(), width, height)
    self.game_screen = game_screen
    self.media_type = nil
    self.data = nil
    self.data_size = nil
    CreatePreviewArea(self)
    CreateLocationField(self)
    CreateFileTypeField(self)
    CreateRemoteLocationField(self)
    _create_cancel_button(self)
    CreateUploadButton(self)
end

function AssetsPanel:set_file(file)
    local data = file:read("data")
    local size = file:getSize()
    self.data = data
    self.data_size = size
    SetFileType(self, data)

    local path = file:getFilename()
    self.location_input:set_text(path)
    local split_path = Utils.split_path(path)

    local file_name = split_path[#split_path]
    self.remoteLocationInput:set_text(file_name)
    self.remoteLocationInput:set_read_only(false)
end

function AssetsPanel:on_resize(w, h)
    Panel.on_resize(self, w, h)
    RefreshActionButtons(self)
end

function AssetsPanel:reset()
    self.preview_area:reset()
    self.location_input:set_text("")
    self.fileTypeInput:set_text("")
    self.remoteLocationInput:set_read_only(true)
    self.remoteLocationInput:set_text("")
    self.media_type = nil
    self.data = nil
    self.data_size = nil
end

function AssetsPanel:_upload()
    app.asset_manager:upload_asset(self.remoteLocationInput:get_text(), self.data)
end

function AssetsPanel:cancel()
    self:reset()
end

function AssetsPanel:release()
    self.preview_area:release()
end

return AssetsPanel

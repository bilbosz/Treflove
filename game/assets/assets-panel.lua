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
    self.previewArea = PreviewArea(self, w, w)
    self.previewArea:set_position(Consts.PADDING, Consts.PADDING)
end

local function CreateLocationLabel(self)
    local text = Text(self, "Local path", Consts.FOREGROUND_COLOR)
    local _, areaY, _, areaH = self.previewArea:get_position_and_size()

    text:set_position(Consts.PADDING, areaY + areaH + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateLocationInput(self)
    local panelW = self:get_size()
    local input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.locationInput = input

    input:set_read_only(true)
    return input
end

local function CreateLocationField(self)
    local text = CreateLocationLabel(self)
    local textX, textY, textW, textH = text:get_position_and_outer_size()

    local input = CreateLocationInput(self)
    input:set_position(textX, textY + textH + Consts.PADDING)
end

local function CreateFileTypeLabel(self)
    local text = Text(self, "File type", Consts.FOREGROUND_COLOR)
    local inputX, inputY, inputW, inputH = self.locationInput:get_position_and_size()

    text:set_position(Consts.PADDING, inputY + inputH + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateFileTypeInput(self)
    local panelW = self:get_size()
    local input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.fileTypeInput = input

    input:set_read_only(true)
    return input
end

local function CreateFileTypeField(self)
    local text = CreateFileTypeLabel(self)
    local textX, textY, _, textH = text:get_position_and_outer_size()
    local input = CreateFileTypeInput(self)
    input:set_position(textX, textY + textH + Consts.PADDING)
end

local function CreateRemoteLocationLabel(self)
    local text = Text(self, "Remote location", Consts.FOREGROUND_COLOR)
    local _, inputY, _, inputH = self.fileTypeInput:get_position_and_size()

    text:set_position(Consts.PADDING, inputY + inputH + Consts.PADDING)
    text:set_scale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateRemoteLocationInput(self)
    local panelW = self:get_size()
    local input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.remoteLocationInput = input

    input:set_read_only(true)
    return input
end

local function CreateRemoteLocationField(self)
    local text = CreateRemoteLocationLabel(self)
    local textX, textY, textW, textH = text:get_position_and_outer_size()
    local input = CreateRemoteLocationInput(self)
    input:set_position(textX, textY + textH + Consts.PADDING)
end

local function RefreshUploadButtonGeometry(self)
    local w, h = self:get_size()
    local button = self.uploadButton
    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local buttonW, buttonH = button:get_size()
    button:set_position(w - buttonW * s - Consts.PADDING, h - buttonH * s - Consts.PADDING)
end

local function RefreshCancelButtonGeometry(self)
    local w, h = self:get_size()
    local button = self.cancelButton
    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local buttonH = select(2, button:get_size())
    button:set_position(Consts.PADDING, h - buttonH * s - Consts.PADDING)
end

local function CreateUploadButton(self)
    local button = TextButton(self, self.gameScreen, "Upload", function()
        self:_upload()
    end)
    self.uploadButton = button

    RefreshUploadButtonGeometry(self)
end

local function _create_cancel_button(self)
    local h = select(2, self:get_size())

    local button = TextButton(self, self.gameScreen, "Cancel", function()
        self:cancel()
    end)
    self.cancelButton = button

    RefreshCancelButtonGeometry(self)
end

local function RefreshActionButtons(self)
    RefreshUploadButtonGeometry(self)
    RefreshCancelButtonGeometry(self)
end

local function SetFileType(self, data)
    local mediaType, medium = Media.GetTypeAndMedium(data)
    self.mediaType = mediaType
    local fileTypePreview = FILE_TYPE_PREVIEW[mediaType]
    if fileTypePreview then
        self.previewArea:SetContent(medium, fileTypePreview)
    end
    self.fileTypeInput:set_text(tostring(table.find_table_key(Media.Type, mediaType)))
end

function AssetsPanel:init(gameScreen, width, height)
    Panel.init(self, gameScreen:get_control(), width, height)
    self.gameScreen = gameScreen
    self.mediaType = nil
    self.data = nil
    self.dataSize = nil
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
    self.dataSize = size
    SetFileType(self, data)

    local path = file:getFilename()
    self.locationInput:set_text(path)
    local splitPath = Utils.split_path(path)

    local fileName = splitPath[#splitPath]
    self.remoteLocationInput:set_text(fileName)
    self.remoteLocationInput:set_read_only(false)
end

function AssetsPanel:on_resize(w, h)
    Panel.on_resize(self, w, h)
    RefreshActionButtons(self)
end

function AssetsPanel:reset()
    self.previewArea:reset()
    self.locationInput:set_text("")
    self.fileTypeInput:set_text("")
    self.remoteLocationInput:set_read_only(true)
    self.remoteLocationInput:set_text("")
    self.mediaType = nil
    self.data = nil
    self.dataSize = nil
end

function AssetsPanel:_upload()
    app.asset_manager:upload_asset(self.remoteLocationInput:get_text(), self.data)
end

function AssetsPanel:cancel()
    self:reset()
end

function AssetsPanel:release()
    self.previewArea:release()
end

return AssetsPanel

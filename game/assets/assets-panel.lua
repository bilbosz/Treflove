AssetsPanel = {}

local FILE_TYPE_PREVIEW = {
    [Media.Type.IMAGE] = PreviewImageArea,
    [Media.Type.AUDIO] = PreviewAudioArea,
    [Media.Type.VIDEO] = PreviewVideoArea,
    [Media.Type.TEXT] = PreviewTextArea,
    [Media.Type.FONT] = PreviewFontArea
}

local function CreatePreviewArea(self)
    local w = self:GetSize() - 2 * Consts.PADDING
    self.previewArea = PreviewArea(self, w, w)
    self.previewArea:SetPosition(Consts.PADDING, Consts.PADDING)
end

local function CreateLocationLabel(self)
    local text = Text(self, "Local path", Consts.FOREGROUND_COLOR)
    local areaX, areaY, areaW, areaH = self.previewArea:GetPositionAndSize()

    text:SetPosition(Consts.PADDING, areaY + areaH + Consts.PADDING)
    text:SetScale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateLocationInput(self)
    local panelW = self:GetSize()
    local input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.locationInput = input

    input:SetReadOnly(true)
    return input
end

local function CreateLocationField(self)
    local text = CreateLocationLabel(self)
    local textX, textY, textW, textH = text:GetPositionAndOuterSize()

    local input = CreateLocationInput(self)
    input:SetPosition(textX, textY + textH + Consts.PADDING)
end

local function CreateFileTypeLabel(self)
    local text = Text(self, "File type", Consts.FOREGROUND_COLOR)
    local inputX, inputY, inputW, inputH = self.locationInput:GetPositionAndSize()

    text:SetPosition(Consts.PADDING, inputY + inputH + Consts.PADDING)
    text:SetScale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateFileTypeInput(self)
    local panelW = self:GetSize()
    local input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.fileTypeInput = input

    input:SetReadOnly(true)
    return input
end

local function CreateFileTypeField(self)
    local text = CreateFileTypeLabel(self)
    local textX, textY, textW, textH = text:GetPositionAndOuterSize()
    local input = CreateFileTypeInput(self)
    input:SetPosition(textX, textY + textH + Consts.PADDING)
end

local function CreateRemoteLocationLabel(self)
    local text = Text(self, "Remote location", Consts.FOREGROUND_COLOR)
    local inputX, inputY, inputW, inputH = self.fileTypeInput:GetPositionAndSize()

    text:SetPosition(Consts.PADDING, inputY + inputH + Consts.PADDING)
    text:SetScale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateRemoteLocationInput(self)
    local panelW = self:GetSize()
    local input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.remoteLocationInput = input

    input:SetReadOnly(true)
    return input
end

local function CreateRemoteLocationField(self)
    local text = CreateRemoteLocationLabel(self)
    local textX, textY, textW, textH = text:GetPositionAndOuterSize()
    local input = CreateRemoteLocationInput(self)
    input:SetPosition(textX, textY + textH + Consts.PADDING)
end

local function CreateUploadButton(self)
    local w, h = self:GetSize()

    local button = TextButton(self, self.gameScreen, "Upload", function()
        self:Upload()
    end)
    self.applyButton = button

    local s = 0.3
    button:SetScale(s)

    local buttonW, buttonH = button:GetSize()
    button:SetPosition(w - buttonW * s - Consts.PADDING, h - buttonH * s - Consts.PADDING)
end

local function CreateCancelButton(self)
    local h = select(2, self:GetSize())

    local button = TextButton(self, self.gameScreen, "Cancel", function()
        self:Cancel()
    end)
    self.cancelButton = button

    local s = 0.3
    button:SetScale(s)

    local buttonH = select(2, button:GetSize())
    button:SetPosition(Consts.PADDING, h - buttonH * s - Consts.PADDING)
end

function AssetsPanel:Init(gameScreen, width, height)
    Panel.Init(self, gameScreen:GetControl(), width, height)
    self.gameScreen = gameScreen
    CreatePreviewArea(self)
    CreateLocationField(self)
    CreateFileTypeField(self)
    CreateRemoteLocationField(self)
    CreateUploadButton(self)
    CreateCancelButton(self)
end

function AssetsPanel:SetFile(file)
    local path = file:getFilename()
    self.locationInput:SetText(path)
    local splitPath = SplitPath(path)

    local fileName = splitPath[#splitPath]
    self.remoteLocationInput:SetText(fileName)
    self.remoteLocationInput:SetReadOnly(false)
end

function AssetsPanel:SetFileType(droppedFile)
    local mediaType, medium = Media.GetTypeAndMedium(droppedFile)
    local fileTypePreview = FILE_TYPE_PREVIEW[mediaType]
    if fileTypePreview then
        self.previewArea:SetContent(medium, fileTypePreview)
    end
    self.fileTypeInput:SetText(tostring(table.findkey(Media.Type, mediaType)))
end

function AssetsPanel:OnResize(w, h)
    Panel.OnResize(self, w, h)
end

function AssetsPanel:Reset()
    self.previewArea:Reset()
    self.locationInput:SetText("")
    self.fileTypeInput:SetText("")
    self.remoteLocationInput:SetReadOnly(true)
    self.remoteLocationInput:SetText("")
end

function AssetsPanel:Upload()
    app:Log("TODO: Asset To Be Uploaded...")
end

function AssetsPanel:Cancel()
    self:Reset()
    app:Log("TODO: Canceled")
end

function AssetsPanel:Release()
    self.previewArea:Release()
end

MakeClassOf(AssetsPanel, Panel)

AssetsPanel = {}

local function CreateDropArea(self)
    local w = self:GetSize() - 2 * Consts.PADDING
    self.dropArea = PreviewArea(self, w, w)
    self.dropArea:SetPosition(Consts.PADDING, Consts.PADDING)
end

local function CreateLocationLabel(self)
    local text = Text(self, "Local path", Consts.FOREGROUND_COLOR)
    local areaX, areaY, areaW, areaH = self.dropArea:GetPositionAndSize()

    text:SetPosition(Consts.PADDING, areaY + areaH + Consts.PADDING)
    text:SetScale(Consts.PANEL_FIELD_SCALE)
    return text
end

local function CreateLocationInput(self)
    local panelW = self:GetSize()
    local input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT)
    self.locationInput = input
    return input
end

local function CreateLocationField(self)
    local text = CreateLocationLabel(self)
    local textX, textY, textW, textH = text:GetPositionAndOuterSize()

    local input = CreateLocationInput(self)
    self.locationInput = input
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
    return input
end

local function CreateFileTypeField(self)
    local text = CreateFileTypeLabel(self)
    local textX, textY, textW, textH = text:GetPositionAndOuterSize()
    local input = CreateFileTypeInput(self)
    input:SetPosition(textX, textY + textH + Consts.PADDING)
end

function AssetsPanel:Init(gameScreen, width, height)
    Panel.Init(self, gameScreen:GetControl(), width, height)
    self.gameScreen = gameScreen
    CreateDropArea(self)
    CreateLocationField(self)
    CreateFileTypeField(self)
end

function AssetsPanel:SetFile(file)
    self.locationInput:SetText(file:getFilename())
end

function AssetsPanel:SetFileType(file)
    local mediaType = Media.GetType(file)

    self.fileTypeInput:SetText(tostring(mediaType))
end

function AssetsPanel:OnResize(w, h)
    Panel.OnResize(self, w, h)
end

function AssetsPanel:Release()
    self.dropArea:Release()
end

MakeClassOf(AssetsPanel, Panel)

PreviewArea = {}

local PREVIEW_STRING = "Preview"
local DROP_FILE_STRING = "Drop File Here"

local function CreateBackgroundLabels(self, str)
    local labels = Control(self)

    local label = Text(nil, str)
    label:SetScale(Consts.PANEL_FIELD_SCALE)
    local w, h = label:GetOuterSize()

    local areaW, areaH = self:GetSize()
    local desiredW, desiredH = areaW * math.sqrt(2), areaH * math.sqrt(2)
    local hor = math.ceil(desiredW / (w + Consts.PADDING) + 0.5)
    local ver = math.ceil(desiredH / (h + Consts.PADDING))
    local labelsW, labelsH = hor * (w + Consts.PADDING), ver * (h + Consts.PADDING)

    local x, y, w, h = 0, 0, nil, nil
    for i = 1, ver do
        for j = 1, hor do
            local label = Text(labels, str, Consts.BACKGROUND_COLOR)
            label:SetScale(Consts.PANEL_FIELD_SCALE)
            label:SetPosition(x, y)
            w, h = label:GetOuterSize()
            x = x + w + Consts.PADDING
        end
        x = (i % 2) * 0.5 * w
        y = y + h + Consts.PADDING
    end

    labels:SetPosition(areaW * 0.5, areaH * 0.5)
    labels:SetOrigin(labelsW * 0.5, labelsH * 0.5)
    labels:SetRotation(math.pi * 0.25)

    return labels
end

local function SetLabels(self, labels)
    for _, v in ipairs({
        self.previewLabels,
        self.dropFileLabels
    }) do
        v:SetEnabled(false)
    end
    labels:SetEnabled(true)
end

local function CreateBackground(self)
    local w, h = self:GetSize()
    local background = Rectangle(self, w, h, Consts.BUTTON_NORMAL_COLOR)
    self.previewLabels = CreateBackgroundLabels(self, PREVIEW_STRING)
    self.dropFileLabels = CreateBackgroundLabels(self, DROP_FILE_STRING)

    SetLabels(self, self.dropFileLabels)
end

local function CreateContentParent(self)
    local control = Control(self)
    self.contentParent = control

    local w, h = self:GetSize()
    control:SetPosition(w * 0.5, h * 0.5)
end

function PreviewArea:Init(parent, width, height)
    ClippingRectangle.Init(self, parent, width, height)
    FileSystemDropEventListener.Init(self, true)
    CreateBackground(self)
    CreateContentParent(self)

    self.preview = nil

    app.fileSystemDropEventManager:RegisterListener(self)
end

function PreviewArea:OnFileSystemDrop(x, y, droppedFile)
    local ok, err = droppedFile:open("r")
    assert(ok, err)
    self.parent:SetFile(droppedFile)
    self.parent:SetFileType(droppedFile)
    droppedFile:close()
end

function PreviewArea:SetContent(loveContent, Preview)
    self:Reset()
    SetLabels(self, self.previewLabels)
    self.preview = Preview(self, loveContent)
end

function PreviewArea:Reset()
    SetLabels(self, self.dropFileLabels)
    if self.preview then
        self.preview:SetParent(nil)
    end
end

function PreviewArea:Release()
    app.fileSystemDropEventManager:UnregisterListener(self)
end

MakeClassOf(PreviewArea, ClippingRectangle, FileSystemDropEventListener)

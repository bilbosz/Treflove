PreviewArea = {}

local LABEL_STRING = "Preview"

local function CreateBackgroundLabels(self)
    local labels = Control(self)
    self.labels = labels

    local label = Text(nil, LABEL_STRING)
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
            local label = Text(labels, LABEL_STRING, Consts.BACKGROUND_COLOR)
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
end

local function CreateBackground(self)
    local w, h = self:GetSize()
    local background = Rectangle(self, w, h, Consts.BUTTON_NORMAL_COLOR)

    CreateBackgroundLabels(self)
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
    app.fileSystemDropEventManager:RegisterListener(self)
end

function PreviewArea:OnFileSystemDrop(x, y, droppedFile)
    local ok, err = droppedFile:open("r")
    assert(ok, err)
    self.parent:SetFile(droppedFile)
    self.parent:SetFileType(droppedFile)
    droppedFile:close()
end

function PreviewArea:SetImage(loveImage)
    self:Reset()

    local areaW, areaH = self:GetSize()
    local image = Image(self.contentParent, loveImage)

    local w, h = image:GetSize()
    local scaleW, scaleH = (areaW - 2 * Consts.PADDING) / w, (areaH - 2 * Consts.PADDING) / h
    local scale = math.min(scaleW, scaleH)
    image:SetScale(scale)
    local outerW, outerH = image:GetOuterSize()

    self.contentParent:SetPosition(areaW * 0.5 - outerW * 0.5, areaH * 0.5 - outerH * 0.5)
end

function PreviewArea:Reset()
    local preview = self.contentParent:GetChildren()[1]
    if preview then
        preview:SetParent(nil)
    end
end

function PreviewArea:Release()
    app.fileSystemDropEventManager:UnregisterListener(self)
end

MakeClassOf(PreviewArea, ClippingRectangle, FileSystemDropEventListener)

PreviewImageArea = {}

local function CreatePreview(self, loveContent)
    local image = Image(self, loveContent)

    local areaW, areaH = self.previewArea:GetSize()
    local w, h = image:GetSize()
    local scaleW, scaleH = (areaW - 2 * Consts.PADDING) / w, (areaH - 2 * Consts.PADDING) / h
    local scale = math.min(scaleW, scaleH)
    image:SetScale(scale)
    local outerW, outerH = image:GetOuterSize()
    image:SetPosition(-outerW * 0.5, -outerH * 0.5)
end

function PreviewImageArea:Init(previewArea, loveContent)
    self.previewArea = previewArea
    Control.Init(self, previewArea.contentParent)
    CreatePreview(self, loveContent)
end

MakeClassOf(PreviewImageArea, Control)

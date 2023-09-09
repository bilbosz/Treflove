PreviewAudioArea = {}

local MUSIC_NOTE_IMAGE_PATH = "game/assets/eighthnote.png"
local MUSIC_NOTE_SYMBOL = "𝅘𝅥𝅮"
local PLAY_SYMBOL = "⏵"
local PAUSE_SYMBOL = "⏸"

local function CreatePreview(self, loveContent)
    local symbol = Text(self, "MUSIC_NOTE_SYMBOL")

    local areaW, areaH = self.previewArea:GetSize()
    local w, h = symbol:GetSize()
    local scaleW, scaleH = (areaW - 2 * Consts.PADDING) / w, (areaH - 2 * Consts.PADDING) / h
    local scale = math.min(scaleW, scaleH)
    symbol:SetScale(scale)
    local outerW, outerH = symbol:GetOuterSize()
    symbol:SetPosition(-outerW * 0.5, -outerH * 0.5)
end

function PreviewAudioArea:Init(previewArea, loveContent)
    self.previewArea = previewArea
    Control.Init(self, previewArea.contentParent)
    CreatePreview(self, loveContent)
end

MakeClassOf(PreviewAudioArea, Control)

local Control = require("controls.control")
local Consts = require("app.consts")
local Image = require("controls.image")

---@class PreviewAudioArea: Control
local PreviewAudioArea = class("PreviewAudioArea", Control)

local MUSIC_NOTE_IMAGE_PATH = "game/assets/eighthnote.png"

local function CreatePreview(self, loveContent)
    local symbol = Image(self, MUSIC_NOTE_IMAGE_PATH)

    local areaW, areaH = self.previewArea:get_size()
    local w, h = symbol:get_size()
    local scaleW, scaleH = (areaW - 2 * Consts.PADDING) / w, (areaH - 2 * Consts.PADDING) / h
    local scale = math.min(scaleW, scaleH)
    symbol:set_scale(scale)
    local outerW, outerH = symbol:get_outer_size()
    symbol:set_position(-outerW * 0.5, -outerH * 0.5)
end

function PreviewAudioArea:init(previewArea, loveContent)
    self.previewArea = previewArea
    Control.init(self, previewArea.contentParent)
    CreatePreview(self, loveContent)
end

return PreviewAudioArea

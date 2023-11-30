local Control = require("controls.control")
local Image = require("controls.image")
local Consts = require("app.consts")

---@class PreviewImageArea: Control
local PreviewImageArea = class("PreviewImageArea", Control)

local function CreatePreview(self, loveContent)
    local image = Image(self, loveContent)

    local areaW, areaH = self.previewArea:get_size()
    local w, h = image:get_size()
    local scaleW, scaleH = (areaW - 2 * Consts.PADDING) / w, (areaH - 2 * Consts.PADDING) / h
    local scale = math.min(scaleW, scaleH)
    image:set_scale(scale)
    local outerW, outerH = image:get_outer_size()
    image:set_position(-outerW * 0.5, -outerH * 0.5)
end

function PreviewImageArea:init(previewArea, loveContent)
    self.previewArea = previewArea
    Control.init(self, previewArea.contentParent)
    CreatePreview(self, loveContent)
end

return PreviewImageArea

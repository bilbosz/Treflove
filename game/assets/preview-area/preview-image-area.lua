local Control = require("controls.control")
local Image = require("controls.image")
local Consts = require("app.consts")

---@class PreviewImageArea: Control
local PreviewImageArea = class("PreviewImageArea", Control)

local function _create_preview(self, love_content)
    local image = Image(self, love_content)

    local area_w, area_h = self.preview_area:get_size()
    local w, h = image:get_size()
    local scale_w, scale_h = (area_w - 2 * Consts.PADDING) / w, (area_h - 2 * Consts.PADDING) / h
    local scale = math.min(scale_w, scale_h)
    image:set_scale(scale)
    local outer_w, outer_h = image:get_outer_size()
    image:set_position(-outer_w * 0.5, -outer_h * 0.5)
end

function PreviewImageArea:init(preview_area, love_content)
    self.preview_area = preview_area
    Control.init(self, preview_area.content_parent)
    _create_preview(self, love_content)
end

return PreviewImageArea

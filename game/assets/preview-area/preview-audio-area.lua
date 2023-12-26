local Control = require("controls.control")
local Consts = require("app.consts")
local Image = require("controls.image")

---@class PreviewAudioArea: Control
local PreviewAudioArea = class("PreviewAudioArea", Control)

local MUSIC_NOTE_IMAGE_PATH = "game/assets/eighthnote.png"

local function _create_preview(self, _)
    local symbol = Image(self, MUSIC_NOTE_IMAGE_PATH)

    local area_w, area_h = self.preview_area:get_size()
    local w, h = symbol:get_size()
    local scale_w, scale_h = (area_w - 2 * Consts.PADDING) / w, (area_h - 2 * Consts.PADDING) / h
    local scale = math.min(scale_w, scale_h)
    symbol:set_scale(scale)
    local outer_w, outer_h = symbol:get_outer_size()
    symbol:set_position(-outer_w * 0.5, -outer_h * 0.5)
end

function PreviewAudioArea:init(preview_area, love_content)
    self.preview_area = preview_area
    Control.init(self, preview_area.content_parent)
    _create_preview(self, love_content)
end

return PreviewAudioArea

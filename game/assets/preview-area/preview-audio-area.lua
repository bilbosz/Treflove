local Consts = require("app.consts")
local Control = require("controls.control")
local Image = require("controls.image")
local MediaPlayer = require("ui.media-player")
local SourcePlayback = require("ui.source-playback")

---@class PreviewAudioArea: Control
---@field _preview_area PreviewArea
local PreviewAudioArea = class("PreviewAudioArea", Control)

local MUSIC_NOTE_IMAGE_PATH = "game/assets/eighthnote.png"

---@param preview_area PreviewArea
---@param medium love.Source
---@param data media.Source
function PreviewAudioArea:init(preview_area, medium, data)
    self._preview_area = preview_area
    Control.init(self, preview_area.content_parent)

    local area_w, area_h = preview_area:get_size()
    local player = MediaPlayer(self, preview_area:get_form_screen(), area_w, SourcePlayback(medium))
    local _, player_h = player:get_size()
    player:set_position(-area_w * 0.5, area_h * 0.5 - player_h)

    local symbol = Image(self, MUSIC_NOTE_IMAGE_PATH)
    local w, h = symbol:get_size()
    local scale = math.min((area_w - 2 * Consts.PADDING) / w, (area_h - player_h - 2 * Consts.PADDING) / h)
    symbol:set_scale(scale)
    local outer_w, outer_h = symbol:get_outer_size()
    symbol:set_position(-outer_w * 0.5, -(player_h + outer_h) * 0.5)
end

return PreviewAudioArea

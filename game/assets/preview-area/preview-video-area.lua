local Consts = require("app.consts")
local Control = require("controls.control")
local MediaPlayer = require("ui.media-player")
local Video = require("controls.video")
local VideoPlayback = require("ui.video-playback")
local media = require("utils.media")

---@class PreviewVideoArea: Control
---@field _preview_area PreviewArea
local PreviewVideoArea = class("PreviewVideoArea", Control)

---@param preview_area PreviewArea
---@param medium love.Video
---@param data media.Source
function PreviewVideoArea:init(preview_area, medium, data)
    self._preview_area = preview_area
    Control.init(self, preview_area.content_parent)

    local area_w, area_h = preview_area:get_size()
    local player = MediaPlayer(self, preview_area:get_form_screen(), area_w, VideoPlayback(medium, media.video_duration(data)))
    local _, player_h = player:get_size()
    player:set_position(-area_w * 0.5, area_h * 0.5 - player_h)

    local video = Video(self, medium)
    local w, h = video:get_size()
    local scale = math.min((area_w - 2 * Consts.PADDING) / w, (area_h - player_h - 2 * Consts.PADDING) / h)
    video:set_scale(scale)
    local outer_w, outer_h = video:get_outer_size()
    video:set_position(-outer_w * 0.5, -(player_h + outer_h) * 0.5)
end

return PreviewVideoArea

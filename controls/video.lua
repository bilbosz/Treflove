local DrawableControl = require("controls.drawable-control")

---@class Video: DrawableControl
---@field private _love_video love.Video
---@field private _max_dimension number The longer side, in texels
local Video = class("Video", DrawableControl)

---@param parent Control|nil
---@param love_video love.Video
function Video:init(parent, love_video)
    self._love_video = love_video
    local w, h = love_video:getDimensions()
    self._max_dimension = math.max(w, h)
    DrawableControl.init(self, parent, w, h, function()
        self:draw_texels(self._love_video, self._max_dimension)
    end)
end

return Video

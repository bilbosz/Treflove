local Playback = require("ui.playback")

---@class VideoPlayback: Playback
---@field private _video love.Video
---@field private _duration number|nil
local VideoPlayback = class("VideoPlayback", Playback)

---@param video love.Video
---@return number|nil
local function _get_source_duration(video)
    ---@type love.Source|nil
    local source = video:getSource()
    local duration = source and source:getDuration()
    if duration and duration > 0 then
        return duration
    end
    return nil
end

---@param video love.Video
---@param duration number|nil Seconds, read from the file: LÖVE tells a video's only through its sound
function VideoPlayback:init(video, duration)
    self._video = video
    self._duration = duration or _get_source_duration(video)
end

function VideoPlayback:play()
    self._video:play()
end

function VideoPlayback:pause()
    self._video:pause()
end

function VideoPlayback:stop()
    self._video:pause()
    self._video:rewind()
end

---@param seconds number
function VideoPlayback:seek(seconds)
    self._video:seek(seconds)
end

---@return number
function VideoPlayback:tell()
    return self._video:tell()
end

---@return boolean
function VideoPlayback:is_playing()
    return self._video:isPlaying()
end

---@return number|nil
function VideoPlayback:get_duration()
    return self._duration
end

return VideoPlayback

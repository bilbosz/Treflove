local Playback = require("ui.playback")

---@class SourcePlayback: Playback
---@field private _source love.Source
local SourcePlayback = class("SourcePlayback", Playback)

---@param source love.Source
function SourcePlayback:init(source)
    self._source = source
end

function SourcePlayback:play()
    self._source:play()
end

function SourcePlayback:pause()
    self._source:pause()
end

function SourcePlayback:stop()
    self._source:stop()
end

---@param seconds number
function SourcePlayback:seek(seconds)
    self._source:seek(seconds)
end

---@return number
function SourcePlayback:tell()
    return self._source:tell()
end

---@return boolean
function SourcePlayback:is_playing()
    return self._source:isPlaying()
end

---@return number|nil
function SourcePlayback:get_duration()
    local duration = self._source:getDuration()
    if duration > 0 then
        return duration
    end
    return nil
end

return SourcePlayback

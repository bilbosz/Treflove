---@class Playback: Object
---@overload fun(): Playback
local Playback = class("Playback")

function Playback:play()
    abstract()
end

function Playback:pause()
    abstract()
end

function Playback:stop()
    abstract()
end

---@param seconds number From the start
function Playback:seek(seconds)
    abstract()
end

---@return number seconds From the start
function Playback:tell()
    return abstract()
end

---@return boolean
function Playback:is_playing()
    return abstract()
end

---@return number|nil seconds Nil when unknown
function Playback:get_duration()
    return abstract()
end

return Playback

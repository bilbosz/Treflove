---@class love.video
---This module is responsible for decoding, controlling, and streaming video files.
---
---It can't draw the videos, see love.graphics.newVideo and LoveVideo objects for that.
local m = {}

-- region LoveVideoStream
---@class LoveVideoStream
---An object which decodes, streams, and controls Videos.
local LoveVideoStream = {}
-- endregion LoveVideoStream
---Creates a new LoveVideoStream. Currently only Ogg Theora video files are supported. VideoStreams can't draw videos, see love.graphics.newVideo for that.
---@param filename string @The file path to the Ogg Theora video file.
---@return LoveVideoStream
---@overload fun(file:LoveFile):LoveVideoStream
function m.newVideoStream(filename)
end

return m

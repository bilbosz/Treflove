---@class love.sound
---This module is responsible for decoding sound files. It can't play the sounds, see love.audio for that.
local m = {}

-- region LoveDecoder
---@class LoveDecoder
---An object which can gradually decode a sound file.
local LoveDecoder = {}
---Creates a new copy of current decoder.
---
---The new decoder will start decoding from the beginning of the audio stream.
---@return LoveDecoder
function LoveDecoder:clone()
end

---Returns the number of bits per sample.
---@return number
function LoveDecoder:getBitDepth()
end

---Returns the number of channels in the stream.
---@return number
function LoveDecoder:getChannelCount()
end

---Gets the duration of the sound file. It may not always be sample-accurate, and it may return -1 if the duration cannot be determined at all.
---@return number
function LoveDecoder:getDuration()
end

---Returns the sample rate of the LoveDecoder.
---@return number
function LoveDecoder:getSampleRate()
end

-- endregion LoveDecoder
-- region LoveSoundData
---@class LoveSoundData
---Contains raw audio samples.
---
---You can not play LoveSoundData back directly. You must wrap a LoveSource object around it.
local LoveSoundData = {}
---Returns the number of bits per sample.
---@return number
function LoveSoundData:getBitDepth()
end

---Returns the number of channels in the LoveSoundData.
---@return number
function LoveSoundData:getChannelCount()
end

---Gets the duration of the sound data.
---@return number
function LoveSoundData:getDuration()
end

---Gets the value of the sample-point at the specified position. For stereo LoveSoundData objects, the data from the left and right channels are interleaved in that order.
---@param i number @An integer value specifying the position of the sample (starting at 0).
---@return number
---@overload fun(i:number, channel:number):number
function LoveSoundData:getSample(i)
end

---Returns the number of samples per channel of the LoveSoundData.
---@return number
function LoveSoundData:getSampleCount()
end

---Returns the sample rate of the LoveSoundData.
---@return number
function LoveSoundData:getSampleRate()
end

---Sets the value of the sample-point at the specified position. For stereo LoveSoundData objects, the data from the left and right channels are interleaved in that order.
---@param i number @An integer value specifying the position of the sample (starting at 0).
---@param sample number @The normalized samplepoint (range -1.0 to 1.0).
---@overload fun(i:number, channel:number, sample:number):void
function LoveSoundData:setSample(i, sample)
end

-- endregion LoveSoundData
---Attempts to find a decoder for the encoded sound data in the specified file.
---@param file LoveFile @The file with encoded sound data.
---@param buffer number @The size of each decoded chunk, in bytes.
---@return LoveDecoder
---@overload fun(filename:string, buffer:number):LoveDecoder
function m.newDecoder(file, buffer)
end

---Creates new LoveSoundData from a filepath, LoveFile, or LoveDecoder. It's also possible to create LoveSoundData with a custom sample rate, channel and bit depth.
---
---The sound data will be decoded to the memory in a raw format. It is recommended to create only short sounds like effects, as a 3 minute song uses 30 MB of memory this way.
---@param filename string @The file name of the file to load.
---@return LoveSoundData
---@overload fun(file:LoveFile):LoveSoundData
---@overload fun(decoder:LoveDecoder):LoveSoundData
---@overload fun(samples:number, rate:number, bits:number, channels:number):LoveSoundData
function m.newSoundData(filename)
end

return m

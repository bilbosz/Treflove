local images = require("graphics.images")
local ogg = require("utils.ogg")

---@class media
local media = {}

---@alias LoveMedium love.Source|love.Image|love.Font|love.Video|nil

---@alias media.Source love.FileData A file's bytes, which every LÖVE constructor takes in place of a path but the video's, which opens its file

---@alias media.Constructor fun(data: media.Source, path: string|nil): LoveMedium Raises when `data` is not of its type, gives nil for data of its type LÖVE cannot open; `path` is where LÖVE reads the file, for a constructor that opens it instead of taking its bytes

---@alias media.Candidate {[1]: media.Constructor, [2]: media.Type}

---@enum media.Type
media.Type = {
    VIDEO = 1,
    AUDIO = 2,
    IMAGE = 3,
    FONT = 4,
    TEXT = 5
}

---@param data media.Source
---@return love.Source
local function _try_create_audio_file(data)
    return love.audio.newSource(data, "static")
end

---@param data media.Source
---@return love.Image
local function _try_create_image_file(data)
    return images.new(data)
end

---@param data media.Source
---@return love.Font
local function _try_create_font_file(data)
    -- the annotations lack the Data variant LÖVE documents for every
    -- constructor that takes a file name
    return love.graphics.newFont(data --[[@as string]] )
end

---@param data media.Source
---@param path string|nil
---@return love.Video|nil video nil when LÖVE cannot open the file here: a dropped file, or a Theora stream it refuses
local function _try_create_video_file(data, path)
    assert(ogg.find_theora(data:getString()), "no Theora stream")
    if not path then
        return nil
    end
    ---@type boolean, love.Video|nil
    local is_ok, video = pcall(love.graphics.newVideo, path, {
        audio = true
    })
    if not is_ok then
        is_ok, video = pcall(love.graphics.newVideo, path)
    end
    return is_ok and video or nil
end

---@type media.Candidate[] Ordered so ambiguous data resolves to the preferred type: a video by its container, since LÖVE opens one only from its file; audio last, since LÖVE's decoders take a font or a video with a Vorbis track for a sound
local MATCH_FILE = {
    {
        _try_create_video_file,
        media.Type.VIDEO
    },
    {
        _try_create_image_file,
        media.Type.IMAGE
    },
    {
        _try_create_font_file,
        media.Type.FONT
    },
    {
        _try_create_audio_file,
        media.Type.AUDIO
    }
}

---@param data media.Source
---@param path string|nil Where LÖVE reads the file, when it can: a file of the store, not a dropped one
---@return media.Type|nil, LoveMedium
function media.get_type_and_medium(data, path)
    for _, v in ipairs(MATCH_FILE) do
        local f, t = unpack(v)
        local is_ok, medium = pcall(f, data, path)
        if is_ok then
            return t, medium
        end
    end
    return nil, nil
end

---@param data media.Source
---@return number|nil seconds nil when the data has no Theora stream or no page with a granule position
function media.video_duration(data)
    return ogg.theora_duration(data:getString())
end

return media

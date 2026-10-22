local images = require("graphics.images")

---@class media
local media = {}

---@alias LoveMedium love.Source|love.Image|love.Font|love.Video|nil

---@alias media.Source love.FileData A file's bytes, which every LÖVE constructor takes in place of a path

---@alias media.Constructor fun(data: media.Source): LoveMedium Raises when `data` is not of its type

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
---@return love.Video
local function _try_create_video_file(data)
    return love.graphics.newVideo(data --[[@as string]] )
end

---@type media.Candidate[] Ordered so ambiguous data resolves to the preferred type
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
        _try_create_audio_file,
        media.Type.AUDIO
    },
    {
        _try_create_font_file,
        media.Type.FONT
    }
}

---@param data media.Source
---@return media.Type|nil, LoveMedium
function media.get_type_and_medium(data)
    for _, v in ipairs(MATCH_FILE) do
        local f, t = unpack(v)
        local is_ok, medium = pcall(f, data)
        if is_ok then
            return t, medium
        end
    end
    return nil, nil
end

return media

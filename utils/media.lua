---@class Media
local Media = class("Media")

Media.Type = {
    VIDEO = 1,
    AUDIO = 2,
    IMAGE = 3,
    FONT = 4,
    TEXT = 5
}

---@param data string
---@return LoveSource
local function _try_create_audio_file(data)
    return love.audio.newSource(data, "static")
end

---@param data string
---@return LoveImage
local function _try_create_image_file(data)
    return love.graphics.newImage(data)
end

---@param data string
---@return LoveFont
local function _try_create_font_file(data)
    return love.graphics.newFont(data)
end

---@param data string
---@return LoveVideo
local function _try_create_video_file(data)
    return love.graphics.newVideo(data)
end

---@type any[]
local MATCH_FILE = {
    {
        _try_create_video_file,
        Media.Type.VIDEO
    },
    {
        _try_create_image_file,
        Media.Type.IMAGE
    },
    {
        _try_create_audio_file,
        Media.Type.AUDIO
    },
    {
        _try_create_font_file,
        Media.Type.FONT
    }
}

---@param data string
---@return string, LoveSource|LoveImage|LoveFont|LoveVideo
function Media.GetTypeAndMedium(data)
    for _, v in ipairs(MATCH_FILE) do
        local f, t = unpack(v)
        local is_ok, medium = pcall(function()
            return f(data)
        end)
        if is_ok then
            return t, medium
        end
    end
    return nil, nil
end

return Media()

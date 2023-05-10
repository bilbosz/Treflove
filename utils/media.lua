Media = {}

Media.Type = {
    VIDEO = 1,
    AUDIO = 2,
    IMAGE = 3,
    FONT = 4,
    TEXT = 5
}

local function TryCreateAudioFile(data)
    return love.audio.newSource(data, "static")
end

local function TryCreateImageFile(data)
    return love.graphics.newImage(data)
end

local function TryCreateFontFile(data)
    return love.graphics.newFont(data)
end

local function TryCreateVideoFile(data)
    return love.graphics.newVideo(data)
end

local MATCH_FILE = {
    {
        TryCreateVideoFile,
        Media.Type.VIDEO
    },
    {
        TryCreateImageFile,
        Media.Type.IMAGE
    },
    {
        TryCreateAudioFile,
        Media.Type.AUDIO
    },
    {
        TryCreateFontFile,
        Media.Type.FONT
    }
}

function Media.GetTypeAndMedium(droppedFile)
    local data = droppedFile:read("data")
    local isOk, asset
    for _, v in ipairs(MATCH_FILE) do
        local f, t = unpack(v)
        isOk, medium = pcall(function()
            return f(data)
        end)
        if isOk then
            return t, medium
        end
    end
    return nil, nil
end

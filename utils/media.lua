Media = {}

Media.Type = {
    TEXT = 1,
    IMAGE = 2,
    FONT = 3,
    VIDEO = 4
}

local function TryCreateTextFile(filePath)
    return love.graphics.newImage(filePath)
end

local function TryCreateImageFile(filePath)
    return love.graphics.newImage(filePath)
end

local function TryCreateVideoFile(filePath)
    return love.graphics.newVideo(filePath)
end

local MatchFile = {
    TryCreateImageFile = Media.Type.TEXT
}

function Media.GetType(filePath)
    local isOk, content
    isOk, content = pcall(function()
        TryCreateImageFile(filePath)
    end)
    return isOk
end

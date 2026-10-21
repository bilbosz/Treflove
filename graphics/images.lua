---@class images
local images = {}

---@alias ImageSource string|love.FileData|love.ImageData|love.CompressedImageData A file path or the decoded or raw file

---@type love.FilterMode
images.FILTER = "linear"
---@type love.FilterMode The filter between two mipmap levels
images.MIPMAP_FILTER = "linear"

---@type table<string, love.Image>
local cache = {}

---An image with its mipmap chain, so a downscaled draw samples the level
---of its on-screen pixel size instead of skipping texels
---@param source ImageSource
---@return love.Image
function images.new(source)
    local image = love.graphics.newImage(source, {
        mipmaps = true
    })
    image:setFilter(images.FILTER, images.FILTER)
    image:setMipmapFilter(images.MIPMAP_FILTER)
    return image
end

---One image per file path, made on first use
---@param path string
---@return love.Image
function images.get(path)
    local image = cache[path]
    if not image then
        image = images.new(path)
        cache[path] = image
    end
    return image
end

---The next `get` of the path reads the file again
---@param path string
function images.forget(path)
    cache[path] = nil
end

function images.clear()
    cache = {}
end

return images

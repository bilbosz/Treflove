local DrawableControl = require("controls.drawable-control")
local Asset = require("data.asset")

---@class Image: DrawableControl
local Image = class("Image", DrawableControl)

---@param parent Control
---@param path_or_love_image string|love.Image
function Image:init(parent, path_or_love_image)
    local love_image
    if type(path_or_love_image) == "string" then
        love_image = love.graphics.newImage(Asset(path_or_love_image, false):get_path() or path_or_love_image)
    else
        love_image = path_or_love_image
    end
    local w, h = love_image:getDimensions()
    DrawableControl.init(self, parent, w, h, function()
        love.graphics.draw(love_image)
    end)
end

return Image

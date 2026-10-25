local images = require("graphics.images")

local DrawableControl = require("controls.drawable-control")
local Asset = require("data.asset")

---@class Image: DrawableControl
---@field private _love_image love.Image
---@field private _max_dimension number The longer side, in texels
local Image = class("Image", DrawableControl)

---@param parent Control|nil
---@param path_or_love_image string|love.Image
function Image:init(parent, path_or_love_image)
    ---@type love.Image
    local love_image
    if type(path_or_love_image) == "string" then
        love_image = images.get(Asset(path_or_love_image, false):get_path() or path_or_love_image)
    else
        love_image = path_or_love_image
    end
    self._love_image = love_image
    local w, h = love_image:getDimensions()
    self._max_dimension = math.max(w, h)
    DrawableControl.init(self, parent, w, h, function()
        self:draw_texels(self._love_image, self._max_dimension)
    end)
end

return Image

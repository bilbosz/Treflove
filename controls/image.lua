local images = require("graphics.images")

local DrawableControl = require("controls.drawable-control")

---@class Image: DrawableControl
---@field private _love_image love.Image
---@field private _max_dimension number The longer side, in texels
local Image = class("Image", DrawableControl)

---@param parent Control|nil
---@param path_or_love_image string|love.Image A path of the joined game's asset store, or else of the source tree
function Image:init(parent, path_or_love_image)
    ---@type love.Image
    local love_image
    if type(path_or_love_image) == "string" then
        local store = app.asset_manager:get_store()
        local stored = store and store:asset(path_or_love_image):get_path()
        love_image = images.get(stored or path_or_love_image)
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

---@return love.Image
function Image:get_love_image()
    return self._love_image
end

return Image

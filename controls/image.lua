local images = require("graphics.images")

local DrawableControl = require("controls.drawable-control")
local Asset = require("data.asset")

---@class Image: DrawableControl
---@field private _love_image love.Image
---@field private _max_dimension number The longer side, in texels
local Image = class("Image", DrawableControl)

---@private
function Image:_draw()
    local scale, is_axis_aligned, tx, ty = self:get_screen_placement()
    if is_axis_aligned then
        -- One texel per screen pixel when the far edge lands within half a
        -- pixel of it, at a whole-pixel position either way, so a pan never
        -- resamples the texels at a drifting sub-pixel offset
        if math.abs(scale - 1) * self._max_dimension <= 0.5 then
            scale = 1
        end
        love.graphics.origin()
        love.graphics.translate(math.floor(tx + 0.5), math.floor(ty + 0.5))
        love.graphics.scale(scale)
    end
    love.graphics.draw(self._love_image)
end

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
        self:_draw()
    end)
end

return Image

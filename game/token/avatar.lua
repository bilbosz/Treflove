local ClippingMask = require("controls.clipping-mask")
local Image = require("controls.image")
local lifetime = require("lifetime")

---@class Avatar: ClippingMask
---@field private _image Image
---@field private _diameter number
local Avatar = class("Avatar", ClippingMask)

---@private
function Avatar:_cover_circle()
    local d = self._diameter
    local r = d * 0.5
    local image = self._image
    local w, h = image:get_size()
    image:set_origin(w * 0.5, h * 0.5)
    image:set_scale(math.max(d / w, d / h))
    image:set_position(r, r)
end

---@param parent Control|nil
---@param path string An image of the joined game's store
---@param diameter number The circle's, in the parent's units; the image covers it, centered
function Avatar:init(parent, path, diameter)
    self._diameter = diameter
    ClippingMask.init(self, parent, diameter, diameter, function()
        local r = self._diameter * 0.5
        love.graphics.circle("fill", r, r, r)
    end)
    self._image = Image(self, path)
    self:_cover_circle()
end

---@return Image
function Avatar:get_image()
    return self._image
end

---@return number
function Avatar:get_diameter()
    return self._diameter
end

---@param diameter number
function Avatar:set_diameter(diameter)
    self._diameter = diameter
    self:set_size(diameter, diameter)
    self:_cover_circle()
end

---@param path string An image of the joined game's store, in place of the one shown
function Avatar:set_image(path)
    lifetime.destroy(self._image)
    self._image = Image(self, path)
    self:_cover_circle()
end

return Avatar

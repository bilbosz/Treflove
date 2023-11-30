local DrawableControl = require("controls.drawable-control")
local Consts = require("app.consts")
local ClippingMask = require("controls.clipping-mask")

---@class Logo: DrawableControl
local Logo = class("Logo", DrawableControl)

function Logo:init(parent)
    local image = love.graphics.newImage("icon.png")
    local imgW, imgH = image:getDimensions()
    local r = imgW * 0.5

    DrawableControl.init(self, parent, imgW, imgW, function()
        love.graphics.setColor(Consts.LOGO_COLOR_BG)
        love.graphics.circle("fill", r, r, r)
    end)
    self:set_origin(r, r)
    self:set_position(parent.size[1] * 0.5, parent.size[2] * 0.5)

    local shader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            if (Texel(texture, texture_coords).a <= 0.35) {
                discard;
            }
            return vec4(1.0);
        }
    ]])
    local mask = ClippingMask(self, imgW, imgH, function()
        love.graphics.setShader(shader)
        love.graphics.draw(image)
        love.graphics.setShader()
    end)
    mask:set_origin(r, imgH * 0.5 - 11)
    mask:set_position(r, r)
    mask:set_scale(0.94)
    self.mask = mask

    self.color = Consts.LOGO_COLOR_FG
    local background = DrawableControl(mask, imgW, imgW, function()
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill", 0, 0, imgW, imgW)
    end)
    background:set_origin(r, r)
    background:set_position(r, r)
end

return Logo

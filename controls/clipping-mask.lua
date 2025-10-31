local Control = require("controls.control")

---@alias StencilCallback fun()
---@alias DrawMaskCallback fun()

---@class ClippingMask: Control
---@field private _stencil_cb StencilCallback
local ClippingMask = class("ClippingMask", Control)

---@param parent Control
---@param width number
---@param height number
---@param draw_mask_cb DrawMaskCallback
function ClippingMask:init(parent, width, height, draw_mask_cb)
    assert(width and height and draw_mask_cb)
    Control.init(self, parent, width, height)
    self:set_draw_mask_callback(draw_mask_cb)
end

function ClippingMask:draw()
    love.graphics.stencil(self._stencil_cb, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    Control.draw(self)
    love.graphics.setStencilTest()
end

---@param draw_mask_cb DrawMaskCallback
function ClippingMask:set_draw_mask_callback(draw_mask_cb)
    self._stencil_cb = function()
        love.graphics.push()
        love.graphics.replaceTransform(self.global_transform)
        draw_mask_cb()
        love.graphics.pop()
    end
end

return ClippingMask

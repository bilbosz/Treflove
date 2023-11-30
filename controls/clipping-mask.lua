local Control = require("controls.control")

---@alias _StencilCallback fun():void
---@alias _DrawMaskCallback fun():void

---@class ClippingMask: Control
---@field private _stencil_cb _StencilCallback
local ClippingMask = class("ClippingMask", Control)

---@param parent Control
---@param width number
---@param height number
---@param draw_mask_cb _DrawMaskCallback
---@return void
function ClippingMask:init(parent, width, height, draw_mask_cb)
    assert(width and height and draw_mask_cb)
    Control.init(self, parent, width, height)
    self:set_draw_mask_callback(draw_mask_cb)
end

---@return void
function ClippingMask:draw()
    love.graphics.stencil(self._stencil_cb, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    Control.draw(self)
    love.graphics.setStencilTest()
end

---@param draw_mask_cb _DrawMaskCallback
---@return void
function ClippingMask:set_draw_mask_callback(draw_mask_cb)
    self._stencil_cb = function()
        love.graphics.push()
        love.graphics.replaceTransform(self.global_transform)
        draw_mask_cb()
        love.graphics.pop()
    end
end

return ClippingMask

ClippingMask = class("ClippingMask", Control)

function ClippingMask:Draw()
    love.graphics.stencil(function()
        self:drawMaskCb()
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    Control.Draw(self)
    love.graphics.setStencilTest()
end

function ClippingMask:Init(parent, width, height, drawMaskCb)
    assert(width and height and drawMaskCb)
    Control.Init(self, parent, width, height)
    self.drawMaskCb = drawMaskCb
end
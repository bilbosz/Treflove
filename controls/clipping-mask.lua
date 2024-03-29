ClippingMask = {}

function ClippingMask:Draw()
    love.graphics.stencil(self.stencilCb, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    Control.Draw(self)
    love.graphics.setStencilTest()
end

function ClippingMask:Init(parent, width, height, drawMaskCb)
    assert(width and height and drawMaskCb)
    Control.Init(self, parent, width, height)
    self:SetDrawMaskCb(drawMaskCb)
end

function ClippingMask:SetDrawMaskCb(drawMaskCb)
    self.stencilCb = function()
        love.graphics.push()
        love.graphics.replaceTransform(self.globalTransform)
        drawMaskCb()
        love.graphics.pop()
    end
end

MakeClassOf(ClippingMask, Control)

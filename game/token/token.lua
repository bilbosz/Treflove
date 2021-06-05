Token = class("Token", ClippingMask)

function Token:CreateImage(path)
    local img = Image(self, path)
    self.image = img

    local imgW, imgH = img:GetSize()
    local selfW, selfH = self:GetSize()
    local scaleW, scaleH = selfW / imgW, selfH / imgH
    img:SetScale(math.max(scaleW, scaleH))
    img:SetOrigin(imgW * 0.5, imgH * 0.5)
end

function Token:Init(parent, width, height, path)
    self.ClippingMask.Init(self, parent, width, height, function()
        local x, y = self:TransformToGlobal(0, 0)
        local scaleX, scaleY = self:GetGlobalScale()
        love.graphics.circle("fill", x, y, width * scaleX * 0.5, height * scaleY * 0.5)
    end)

    self:CreateImage(path)
end


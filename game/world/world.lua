World = class("World", Clipping)

function World:CenterBackground()
    local w, h = self.background:GetSize()
    local bg = self.background
    local scale = self.scaleToPixelsPerMeter * self.worldWidth / w
    bg:SetScale(scale)
    bg:SetOrigin(w * 0.5, h * 0.5)
    bg:SetPosition(self.width * 0.5, self.height * 0.5)
end

function World:Init(parent, width, height, path, worldWidth)
    self.Clipping.Init(self, parent, width, height)
    self.path = path
    self.worldWidth = worldWidth
    self.scaleToPixelsPerMeter = 10

    self.background = Image(self, path)
    self:CenterBackground()
end

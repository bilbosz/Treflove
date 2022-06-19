Panel = {}

local function CreateBackground(self)
    local w, h = self:GetSize()
    self.background = Rectangle(self, w, h, Consts.BACKGROUND_COLOR)
end

function Panel:SetSize(w, h)
    Control.SetSize(self, w, h)
    self.background:SetSize(w, h)
end

function Panel:Init(parent, width, height)
    ClippingRectangle.Init(self, parent, width, height)
    CreateBackground(self)
end

MakeClassOf(Panel, ClippingRectangle)

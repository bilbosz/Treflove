Screen = {}

function Screen:Init()
    self.screen = Control()
end

function Screen:Show(...)
    assert(not self.screen:GetParent())
    self.screen:SetParent(app.root)
end

function Screen:Hide()
    assert(self.screen:GetParent())
    self.screen:SetParent(nil)
end

function Screen:OnResize(w, h)

end

function Screen:GetControl()
    return self.screen
end

MakeClassOf(Screen)

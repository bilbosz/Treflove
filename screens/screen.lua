Screen = {}

function Screen:Init()
    self.screen = nil
end

function Screen:Show(...)
    self.screen = Control(app.root)
end

function Screen:Hide()
    self.screen:SetParent(nil)
    self.screen = nil
end

function Screen:GetControl()
    return self.screen
end

MakeClassOf(Screen)

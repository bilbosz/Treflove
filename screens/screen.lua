Screen = {}

function Screen:Init()
    self.screen = nil
end

function Screen:OnPush(...)
    self.screen = Control(app.root)
end

function Screen:OnPop()
    self.screen:SetParent(nil)
    self.screen = nil
end

function Screen:OnBackground()
    self.screen:SetEnable(false)
end

function Screen:OnForeground()
    self.screen:SetEnable(true)
end

function Screen:GetControl()
    return self.screen
end

MakeClassOf(Screen)

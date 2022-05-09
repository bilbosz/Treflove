ScreenManager = {}

function ScreenManager:Init()
    self.screen = nil
end

function ScreenManager:Show(screen, ...)
    if self.screen then
        self.screen:Hide()
    end
    self.screen = screen
    screen:Show(...)
end

function ScreenManager:OnResize()
    self.screen:Hide()
    self.screen:Show()
end

function ScreenManager:GetScreen()
    return self.screen
end

MakeClassOf(ScreenManager)

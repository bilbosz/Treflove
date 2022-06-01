ScreenManager = {}

function ScreenManager:Init()
    self.screen = nil
    if app.resizeManager then
        app.resizeManager:RegisterListener(self)
    end
end

function ScreenManager:Show(screen, ...)
    if self.screen then
        self.screen:Hide()
    end
    self.screen = screen
    screen:Show(...)
end

function ScreenManager:OnResize(...)
    if not self.screen then
        return
    end
    self.screen:OnResize(...)
end

function ScreenManager:GetScreen()
    return self.screen
end

MakeClassOf(ScreenManager, ResizeEventListener)

ScreenManager = {}

function ScreenManager:Init()
    self.stack = {}
end

function ScreenManager:Push(screen, ...)
    local top = self:Top()
    if top then
        top:OnBackground()
    end
    table.insert(self.stack, screen)
    screen:OnPush(...)
end

function ScreenManager:Pop()
    local top = table.remove(self.stack)
    if top then
        top:OnPop()
    end
    top = self:Top()
    if top then
        top:OnForeground()
    end
end

function ScreenManager:Top()
    return self.stack[#self.stack]
end

MakeClassOf(ScreenManager)

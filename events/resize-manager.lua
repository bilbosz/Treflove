ResizeEventListener = {}

function ResizeEventListener:OnResize(width, height)

end

MakeClassOf(ResizeEventListener)

ResizeManager = {}

local function UpdateNonFsSize(self)
    if not self:GetFullscreen() then
        self.width, self.height = self:GetDimensions()
    end
end

function ResizeManager:Init()
    self.width = config.window.width or 0
    self.height = config.window.height or 0
    UpdateNonFsSize(self)
    EventManager.Init(self, ResizeEventListener)
end

function ResizeManager:Resize()
    UpdateNonFsSize(self)
    app:RescaleRoot()
    self:InvokeEvent(ResizeEventListener.OnResize, app.width, app.height)
end

function ResizeManager:GetDimensions()
    return love.graphics.getDimensions()
end

function ResizeManager:ToggleFullscreen()
    self:SetFullscreen(not self:GetFullscreen())
end

function ResizeManager:SetFullscreen(value)
    love.window.updateMode(self.width, self.height, {
        fullscreen = value,
        fullscreentype = "desktop"
    })
    self:Resize()
end

function ResizeManager:GetFullscreen()
    return love.window.getFullscreen()
end

MakeClassOf(ResizeManager, EventManager)

OptionsManager = {}

function OptionsManager:Init()
    assert(config.window.width and config.window.height)
    self.defaultWidth, self.defaultHeight = config.window.width, config.window.height
end

function OptionsManager:ToggleFullscreen()
    love.window.updateMode(self.defaultWidth, self.defaultHeight, {
        fullscreen = not love.window.getFullscreen(),
        fullscreentype = "desktop"
    })
    app:RescaleRoot()
    app.notificationManager:OnResize()
    app.screenManager:OnResize()
end

MakeClassOf(OptionsManager)

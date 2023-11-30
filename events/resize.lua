local EventManager = require("events.event-manager")

---@class ResizeEventListener
local ResizeEventListener = class("ResizeEventListener")

function ResizeEventListener:on_resize(width, height)

end

---@class ResizeManager: EventManager
local ResizeManager = class("ResizeManager", EventManager)

local function UpdateNonFsSize(self)
    if not self:get_fullscreen() then
        self.width, self.height = self:get_dimensions()
    end
end

function ResizeManager:init()
    self.width = config.window.width or 0
    self.height = config.window.height or 0
    UpdateNonFsSize(self)
    EventManager.init(self, ResizeEventListener)
end

function ResizeManager:resize()
    UpdateNonFsSize(self)
    app:rescale_root()
    self:invoke_event(ResizeEventListener.on_resize, app.width, app.height)
end

function ResizeManager:get_dimensions()
    return love.graphics.getDimensions()
end

function ResizeManager:toggle_fullscreen()
    self:set_fullscreen(not self:get_fullscreen())
end

function ResizeManager:set_fullscreen(value)
    love.window.updateMode(self.width, self.height, {
        fullscreen = value,
        fullscreentype = "desktop"
    })
    self:resize()
end

function ResizeManager:get_fullscreen()
    return love.window.getFullscreen()
end

return {
    Listener = ResizeEventListener,
    Manager = ResizeManager
}

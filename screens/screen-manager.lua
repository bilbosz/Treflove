local ResizeEventListener = require("events.resize").Listener

---@class ScreenManager: ResizeEventListener
local ScreenManager = class("ScreenManager", ResizeEventListener)

function ScreenManager:init()
    self.screen = nil
    if app.resize_manager then
        app.resize_manager:register_listener(self)
    end
end

function ScreenManager:show(screen, ...)
    if self.screen then
        self.screen:hide()
    end
    self.screen = screen
    screen:show(...)
end

function ScreenManager:on_resize(...)
    if not self.screen then
        return
    end
    self.screen:on_resize(...)
end

function ScreenManager:get_screen()
    return self.screen
end

return ScreenManager

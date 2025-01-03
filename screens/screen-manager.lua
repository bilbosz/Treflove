local ResizeEventListener = require("events.resize").Listener

---@class ScreenManager: ResizeEventListener
---@field private _screen Screen
local ScreenManager = class("ScreenManager", ResizeEventListener)

function ScreenManager:init()
    self._screen = nil
    if app.resize_manager then
        app.resize_manager:register_listener(self)
    end
end

---@param screen Screen
---@param ... vararg
function ScreenManager:show(screen, ...)
    if self._screen then
        self._screen:hide()
    end
    self._screen = screen
    screen:show(...)
end

---@param w number
---@param h number
function ScreenManager:on_resize(w, h)
    if not self._screen then
        return
    end
    self._screen:on_resize(w, h)
end

---@return Screen
function ScreenManager:get_screen()
    return self._screen
end

return ScreenManager

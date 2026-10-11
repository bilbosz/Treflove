---@class ScreenManager
---@field private _screen Screen|nil
local ScreenManager = class("ScreenManager")

function ScreenManager:init()
    self._screen = nil
    if app.resize_manager then
        app.resize_manager.resized:register(self, self.on_resize)
    end
end

---@param screen Screen
---@param ... any Arguments forwarded to the screen's `show`
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

---@return Screen|nil
function ScreenManager:get_screen()
    return self._screen
end

return ScreenManager

local EventManager = require("events.event-manager")

---@class ResizeEventListener
local ResizeEventListener = class("ResizeEventListener")

---@param width number
---@param height number
function ResizeEventListener:on_resize(width, height)

end

---@class ResizeManager: EventManager
---@field _width number Remembered non-fullscreen window width
---@field _height number Remembered non-fullscreen window height
local ResizeManager = class("ResizeManager", EventManager)

---@param self ResizeManager
local function _update_non_fs_size(self)
    if not self:get_fullscreen() then
        self._width, self._height = self:get_dimensions()
    end
end

function ResizeManager:init()
    self._width = config.window.width or 0
    self._height = config.window.height or 0
    _update_non_fs_size(self)
    EventManager.init(self, ResizeEventListener)
end

function ResizeManager:resize()
    _update_non_fs_size(self)
    app:rescale_root()
    self:invoke_event(ResizeEventListener.on_resize, app.width, app.height)
end

---@return number, number
function ResizeManager:get_dimensions()
    return love.graphics.getDimensions()
end

function ResizeManager:toggle_fullscreen()
    self:set_fullscreen(not self:get_fullscreen())
end

---@param value boolean
function ResizeManager:set_fullscreen(value)
    love.window.updateMode(self._width, self._height, {
        fullscreen = value,
        fullscreentype = "desktop"
    })
    self:resize()
end

---@return boolean
function ResizeManager:get_fullscreen()
    return (love.window.getFullscreen())
end

return {
    Listener = ResizeEventListener,
    Manager = ResizeManager
}

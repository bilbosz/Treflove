local Event = require("events.event")

---@class ResizeManager: Object
---@field public resized Event Triggered with (width, height) of the rescaled root after every resize
---@field private _width number Remembered non-fullscreen window width
---@field private _height number Remembered non-fullscreen window height
local ResizeManager = class("ResizeManager")

---@private
function ResizeManager:_update_non_fs_size()
    if not self:get_fullscreen() then
        self._width, self._height = self:get_dimensions()
    end
end

function ResizeManager:init()
    self._width = config.window.width or 0
    self._height = config.window.height or 0
    self:_update_non_fs_size()
    self.resized = Event()
end

function ResizeManager:resize()
    self:_update_non_fs_size()
    app:rescale_root()
    self.resized:trigger(app.width, app.height)
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

return ResizeManager

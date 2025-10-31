local Control = require("controls.control")

---@alias DrawCb fun()

---@class DrawableControl: Control
---@field private _draw_cb DrawCb
local DrawableControl = class("DrawableControl", Control)

---@param parent Control|nil
---@param width number
---@param height number
---@param draw_cb DrawCb
function DrawableControl:init(parent, width, height, draw_cb)
    Control.init(self, parent, width, height)
    assert(draw_cb)
    self._draw_cb = draw_cb
end

function DrawableControl:draw()
    love.graphics.push()
    love.graphics.replaceTransform(self.global_transform)
    love.graphics.setColor(1, 1, 1, 1)
    self._draw_cb()
    love.graphics.pop()
    Control.draw(self)
end

---@protected
---@param draw_cb DrawCb
function DrawableControl:set_draw_callback(draw_cb)
    self._draw_cb = draw_cb
end

return DrawableControl

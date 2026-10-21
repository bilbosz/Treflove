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

---What the global transform does to the screen: the scale of a model unit in
---pixels, whether the axes are kept (no rotation, no mirroring, one scale both
---ways) and the position of the origin
---@protected
---@return number scale
---@return boolean is_axis_aligned
---@return number tx
---@return number ty
function DrawableControl:get_screen_placement()
    local a, c, _, tx, b, d, _, ty = self.global_transform:getMatrix()
    local scale = math.sqrt(a * a + b * b)
    local is_axis_aligned = b == 0 and c == 0 and a > 0 and math.abs(a - d) <= 1e-6 * a
    return scale, is_axis_aligned, tx, ty
end

return DrawableControl

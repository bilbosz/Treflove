local Control = require("controls.control")

---@alias DrawCb fun() Draws the control in its local coordinates, under its global transform

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

---@protected
---@param drawable love.Drawable
---@param max_dimension number The drawable's longer side, in texels
function DrawableControl:draw_texels(drawable, max_dimension)
    local scale, is_axis_aligned, tx, ty = self:get_screen_placement()
    if is_axis_aligned then
        -- One texel per screen pixel when the far edge lands within half a
        -- pixel of it, at a whole-pixel position either way, so a pan never
        -- resamples the texels at a drifting sub-pixel offset
        if math.abs(scale - 1) * max_dimension <= 0.5 then
            scale = 1
        end
        love.graphics.origin()
        love.graphics.translate(math.floor(tx + 0.5), math.floor(ty + 0.5))
        love.graphics.scale(scale)
    end
    love.graphics.draw(drawable)
end

return DrawableControl

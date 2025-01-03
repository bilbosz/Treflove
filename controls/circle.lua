local DrawableControl = require("controls.drawable-control")

---@class Circle: DrawableControl
---@field private _color number[]
---@field private _diameter number
---@field private _line_width number
---@field private _radius number
local Circle = class("Circle", DrawableControl)

---@param parent Control
---@param radius number
---@param color number[]
---@param line_width number
function Circle:init(parent, radius, color, line_width)
    local r = radius
    local d = r * 2
    local w = line_width

    DrawableControl.init(self, parent, d, d, function()
        love.graphics.setColor(color)
        love.graphics.setLineWidth(w)
        love.graphics.circle("line", r, r, r)
    end)

    self._radius = r
    self._diameter = d
    self._line_width = w
    self._color = color
end

---@param radius number
function Circle:set_radius(radius)
    local r = radius
    local d = r * 2
    local w = self._line_width
    local color = self._color

    DrawableControl.set_size(self, d, d)
    self:set_draw_callback(function()
        love.graphics.setColor(color)
        love.graphics.setLineWidth(w)
        love.graphics.circle("line", r, r, r)
    end)

    self._radius = r
    self._diameter = d
end

return Circle

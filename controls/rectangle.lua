local Control = require("controls.control")

---@class Rectangle: Control
---@field private _color number[]
---@field private _mode string
local Rectangle = class("Rectangle", Control)

---@param parent Control
---@param width number
---@param height number
---@param color number[]
---@param border_only boolean|nil
---@return void
function Rectangle:init(parent, width, height, color, border_only)
    assert(width and height)
    Control.init(self, parent, width, height)
    self._color = color or {
        1,
        1,
        1,
        1
    }
    self._mode = border_only and "line" or "fill"
end

---@param color number[]
---@return void
function Rectangle:set_color(color)
    self._color = color
end

---@return number[]
function Rectangle:get_color()
    return self._color
end

---@return void
function Rectangle:draw()
    love.graphics.push()
    love.graphics.setColor(unpack(self._color))
    do
        love.graphics.replaceTransform(self.global_transform)
        love.graphics.rectangle(self._mode, 0, 0, unpack(self.size))
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
    Control.draw(self)
end

return Rectangle

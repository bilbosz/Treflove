local Control = require("controls.control")

---@class Rectangle: Control
---@field private _color number[]
---@field private _mode love.DrawMode
local Rectangle = class("Rectangle", Control)

---@param parent Control|nil
---@param width number
---@param height number
---@param color number[]|nil
---@param border_only boolean|nil
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
function Rectangle:set_color(color)
    self._color = color
end

---@return number[]
function Rectangle:get_color()
    return self._color
end

function Rectangle:draw()
    love.graphics.push()
    love.graphics.setColor(unpack(self._color))
    do
        love.graphics.replaceTransform(self.global_transform)
        local w, h = self:get_size()
        if self._mode == "line" then
            local inset = love.graphics.getLineWidth() * 0.5
            love.graphics.rectangle("line", inset, inset, w - 2 * inset, h - 2 * inset)
        else
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
    Control.draw(self)
end

return Rectangle

local DrawableControl = require("controls.drawable-control")

---@class Triangle: DrawableControl
---@field private _color number[]
local Triangle = class("Triangle", DrawableControl)

---@param parent Control|nil
---@param width number
---@param height number
---@param color number[]|nil
function Triangle:init(parent, width, height, color)
    DrawableControl.init(self, parent, width, height, function()
        self:_draw()
    end)
    self._color = color or {
        1,
        1,
        1,
        1
    }
end

---@private
function Triangle:_draw()
    local w, h = self:get_size()
    love.graphics.setColor(self._color)
    love.graphics.polygon("fill", 0, 0, w, 0, w * 0.5, h)
end

---@param color number[]
function Triangle:set_color(color)
    self._color = color
end

---@return number[]
function Triangle:get_color()
    return self._color
end

return Triangle

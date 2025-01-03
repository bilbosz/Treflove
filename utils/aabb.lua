local Utils = require("utils.utils")

---@class Aabb
---@field private _data number[]
local Aabb = class("Aabb")

function Aabb:init()
    self._data = {
        math.huge,
        math.huge,
        -math.huge,
        -math.huge
    }
end

---@return number, number, number, number
function Aabb:get_bounds()
    return unpack(self._data)
end

---@return number, number, number, number
function Aabb:get_position_and_size()
    return self._data[1], self._data[2], self._data[3] - self._data[1], self._data[4] - self._data[2]
end

---@param x number
---@param y number
---@param w number
---@param h number
function Aabb:set_position_and_size(x, y, w, h)
    self._data[1], self._data[2], self._data[3], self._data[4] = x, y, x + w, y + h
end

---@return number
function Aabb:get_min_x()
    return self._data[1]
end

---@return number
function Aabb:get_min_y()
    return self._data[2]
end

---@return number
function Aabb:get_max_x()
    return self._data[3]
end

---@return number
function Aabb:get_max_y()
    return self._data[4]
end

---@param x number
---@param y number
function Aabb:add_point(x, y)
    local min_x, min_y, max_x, max_y = unpack(self._data)
    self._data = {
        math.min(min_x, x),
        math.min(min_y, y),
        math.max(max_x, x),
        math.max(max_y, y)
    }
end

---@param other Aabb
function Aabb:add_aabb(other)
    assert_type(other, Aabb)
    local min_x, min_y, max_x, max_y = unpack(self._data)
    self._data = {
        math.min(min_x, other._data[1]),
        math.min(min_y, other._data[2]),
        math.max(max_x, other._data[3]),
        math.max(max_y, other._data[4])
    }
end

---@param other Aabb
function Aabb:set(other)
    self._data = table.copy(other._data)
end

function Aabb:reset()
    self._data[1] = math.huge
    self._data[2] = math.huge
    self._data[3] = -math.huge
    self._data[4] = -math.huge
end

---@param x number
---@param y number
---@return boolean
function Aabb:is_point_inside(x, y)
    local min_x, min_y, max_x, max_y = unpack(self._data)
    return x >= min_x and x <= max_x and y >= min_y and y <= max_y
end

---@return number
function Aabb:get_width()
    return self._data[3] - self._data[1]
end

---@return number
function Aabb:get_height()
    return self._data[4] - self._data[2]
end

---@param other Aabb
---@return boolean
function Aabb:is_intersecting(other)
    assert_type(other, Aabb)
    local a_min_x, a_min_y, a_max_x, a_max_y = unpack(self._data)
    local b_min_x, b_min_y, b_max_x, b_max_y = unpack(other._data)
    return a_min_x <= b_max_x and a_min_y <= b_max_y or a_max_x >= b_min_x and a_max_y >= b_min_y
end

---@return number, number
function Aabb:get_position()
    return self._data[1], self._data[2]
end

---@return number, number
function Aabb:get_size()
    return self._data[3] - self._data[1], self._data[4] - self._data[2]
end

---@param x number
---@param y number
---@param r number
---@return boolean
function Aabb:is_intersecting_circle(x, y, r)
    if self:is_point_inside(x, y) then
        return true
    end
    local min_x, min_y, max_x, max_y = unpack(self._data)
    local cx = Utils.clamp(min_x, max_x, x)
    local cy = Utils.clamp(min_y, max_y, y)
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r
end

return Aabb

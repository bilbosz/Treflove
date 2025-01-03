local Utils = require("utils.utils")

---@class Aabb
---@field private [1] number
---@field private [2] number
---@field private [3] number
---@field private [4] number
local Aabb = class("Aabb")

function Aabb:init()
    self[1] = math.huge
    self[2] = math.huge
    self[3] = -math.huge
    self[4] = -math.huge
end

---@return number, number, number, number
function Aabb:get_bounds()
    return self[1], self[2], self[3], self[4]
end

---@return number, number, number, number
function Aabb:get_position_and_size()
    return self[1], self[2], self[3] - self[1], self[4] - self[2]
end

---@param x number
---@param y number
---@param w number
---@param h number
function Aabb:set_position_and_size(x, y, w, h)
    self[1], self[2], self[3], self[4] = x, y, x + w, y + h
end

---@return number
function Aabb:get_min_x()
    return self[1]
end

---@return number
function Aabb:get_min_y()
    return self[2]
end

---@return number
function Aabb:get_max_x()
    return self[3]
end

---@return number
function Aabb:get_max_y()
    return self[4]
end

---@param x number
---@param y number
function Aabb:add_point(x, y)
    local min_x, min_y, max_x, max_y = self[1], self[2], self[3], self[4]
    self[1] = math.min(min_x, x)
    self[2] = math.min(min_y, y)
    self[3] = math.max(max_x, x)
    self[4] = math.max(max_y, y)
end

---@param other Aabb
function Aabb:add_aabb(other)
    assert_type(other, Aabb)
    local min_x, min_y, max_x, max_y = self[1], self[2], self[3], self[4]
    self[1] = math.min(min_x, other[1])
    self[2] = math.min(min_y, other[2])
    self[3] = math.max(max_x, other[3])
    self[4] = math.max(max_y, other[4])
end

---@param other Aabb
function Aabb:set(other)
    self[1] = other[1]
    self[2] = other[2]
    self[3] = other[3]
    self[4] = other[4]
end

function Aabb:reset()
    self[1] = math.huge
    self[2] = math.huge
    self[3] = -math.huge
    self[4] = -math.huge
end

---@param x number
---@param y number
---@return boolean
function Aabb:is_point_inside(x, y)
    local min_x, min_y, max_x, max_y = self[1], self[2], self[3], self[4]
    return x >= min_x and x <= max_x and y >= min_y and y <= max_y
end

---@return number
function Aabb:get_width()
    return self[3] - self[1]
end

---@return number
function Aabb:get_height()
    return self[4] - self[2]
end

---@param other Aabb
---@return boolean
function Aabb:is_intersecting(other)
    assert_type(other, Aabb)
    local a_min_x, a_min_y, a_max_x, a_max_y = self[1], self[2], self[3], self[4]
    local b_min_x, b_min_y, b_max_x, b_max_y = other[1], other[2], other[3], other[4]
    return a_min_x <= b_max_x and a_min_y <= b_max_y or a_max_x >= b_min_x and a_max_y >= b_min_y
end

---@return number, number
function Aabb:get_position()
    return self[1], self[2]
end

---@return number, number
function Aabb:get_size()
    return self[3] - self[1], self[4] - self[2]
end

---@param x number
---@param y number
---@param r number
---@return boolean
function Aabb:is_intersecting_circle(x, y, r)
    if self:is_point_inside(x, y) then
        return true
    end
    local min_x, min_y, max_x, max_y = self[1], self[2], self[3], self[4]
    local cx = Utils.clamp(min_x, max_x, x)
    local cy = Utils.clamp(min_y, max_y, y)
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r
end

return Aabb

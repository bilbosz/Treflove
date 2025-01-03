local Aabb = require("utils.aabb")
local Tree = require("utils.tree")

---@class Control: Tree
---@field private _global_aabb LoveTransform
---@field private _is_enabled boolean
---@field private _is_visable boolean
---@field private _local_transform LoveTransform
---@field private _origin number[]
---@field private _position number[]
---@field private _rotation number
---@field private _scale number[]
---@field protected global_transform LoveTransform
---@field protected size number[]
local Control = class("Control", Tree)

-- Transformations
-- * Link: https://learnopengl.com/Getting-started/Transformations
-- * Order:
--   * Origin
--   * Scaling
--   * Rotation
--   * Position

---@private
function Control:_update_local_transform()
    self._local_transform = self._local_transform:setTransformation(self._position[1], self._position[2], self._rotation, self._scale[1], self._scale[2], self._origin[1], self._origin[2])
end

---@private
function Control:_update_global_transform()
    if self.parent then
        self.global_transform:setMatrix(self.parent.global_transform:getMatrix())
    else
        self.global_transform:setMatrix(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    end
    self.global_transform:apply(self._local_transform)

    for _, child in ipairs(self.children) do
        child:_update_global_transform()
    end
end

---@private
function Control:_update_global_aabb_children()
    self._global_aabb:set(self:get_global_aabb())
    local aabb = self._global_aabb
    for _, child in ipairs(self.children) do
        if child:is_enabled() then
            child:_update_global_aabb_children()
            aabb:add_aabb(child._global_aabb)
        end
    end
end

---@private
function Control:_update_global_aabb_parent()
    local parent = self:get_parent()
    while parent do
        parent._global_aabb:set(parent:get_global_aabb())
        local aabb = parent._global_aabb
        for _, child in ipairs(parent.children) do
            if child:is_enabled() then
                aabb:add_aabb(child._global_aabb)
            end
        end
        parent = parent:get_parent()
    end
end

---@private
function Control:_update_global_aabb()
    self:_update_global_aabb_children()
    self:_update_global_aabb_parent()
end

---@private
function Control:_update_transform()
    self:_update_local_transform()
    self:_update_global_transform()
    self:_update_global_aabb()
end

---@private
function Control:_reset_local_transform()
    self._position = {
        0,
        0
    }
    self._scale = {
        1,
        1
    }
    self._rotation = 0
    self._origin = {
        0,
        0
    }
    self:_update_local_transform()
end

---@param x number
---@param y number
---@return number, number
function Control:transform_to_local(x, y)
    return self.global_transform:inverseTransformPoint(x, y)
end

---@param x number
---@param y number
---@return number, number
function Control:transform_to_global(x, y)
    return self.global_transform:transformPoint(x, y)
end

---@param x number|nil
---@param y number|nil
function Control:set_position(x, y)
    assert(x or y)
    if x then
        self._position[1] = x
    end
    if y then
        self._position[2] = y
    end
    self:_update_transform()
end

---@return number, number
function Control:get_position()
    return unpack(self._position)
end

---@param scale_x number
---@param scale_y number
function Control:set_scale(scale_x, scale_y)
    assert(scale_x)
    scale_y = scale_y or scale_x
    self._scale[1] = scale_x
    self._scale[2] = scale_y
    self:_update_transform()
end

---@return number, number
function Control:get_scale()
    return unpack(self._scale)
end

---@param rotation number
function Control:set_rotation(rotation)
    assert(rotation)
    self._rotation = rotation
    self:_update_transform()
end

---@return number
function Control:get_rotation()
    return self._rotation
end

---@param x number
---@param y number
function Control:set_origin(x, y)
    assert(x or y)
    if x then
        self._origin[1] = x
    end
    if y then
        self._origin[2] = y
    end
    self:_update_transform()
end

---@return number, number
function Control:get_origin()
    return unpack(self._origin)
end

---@param child Tree
function Control:add_child(child)
    Tree.add_child(self, child)
    child:_update_global_transform()
    child:_update_global_aabb()
end

---@return number, number, number, number
function Control:get_position_and_size()
    return self._position[1], self._position[2], self.size[1], self.size[2]
end

---@return number, number, number, number
function Control:get_position_and_outer_size()
    return self._position[1], self._position[2], self.size[1] * self._scale[1], self.size[2] * self._scale[2]
end

---@return Aabb
function Control:get_aabb()
    local aabb = Aabb()
    aabb:set_position_and_size(self:get_position_and_size())
    return aabb
end

---@return Aabb
function Control:get_global_aabb()
    local w, h = self:get_size()
    local aabb = Aabb()
    aabb:add_point(self:transform_to_global(0, 0))
    aabb:add_point(self:transform_to_global(w, 0))
    aabb:add_point(self:transform_to_global(w, h))
    aabb:add_point(self:transform_to_global(0, h))
    return aabb
end

---@private
---@param reference_transform LoveTransform
---@return Aabb
function Control:_get_recursive_aabb_detail(reference_transform)
    local aabb = Aabb()
    local diff = reference_transform:inverse():apply(self.global_transform)
    local w, h = self:get_size()

    aabb:add_point(diff:transformPoint(0, 0))
    aabb:add_point(diff:transformPoint(w, 0))
    aabb:add_point(diff:transformPoint(w, h))
    aabb:add_point(diff:transformPoint(0, h))
    ---@type Control[]
    local children = self:get_children()
    for _, child in ipairs(children) do
        aabb:add_aabb(child:_get_recursive_aabb_detail(reference_transform))
    end
    return aabb
end

---@param ctrl Control
---@return Aabb
function Control:get_recursive_aabb(ctrl)
    ctrl = ctrl or self
    return ctrl:_get_recursive_aabb_detail(self.global_transform)
end

---@return Aabb
function Control:get_global_recursive_aabb()
    return self._global_aabb
end

---@param width number
---@param height number
function Control:set_size(width, height)
    assert(math.min(0, width, height) >= 0)
    self.size[1], self.size[2] = width, height
    self:_update_transform()
end

---@return number, number
function Control:get_size()
    return unpack(self.size)
end

---@return number, number
function Control:get_outer_size()
    return self.size[1] * self._scale[1], self.size[2] * self._scale[2]
end

---@param value boolean
function Control:set_enabled(value)
    self._is_enabled = value
    if value and self.parent then
        self.parent:_update_global_aabb()
    end
end

---@return boolean
function Control:is_enabled()
    return self._is_enabled
end

---@return boolean
function Control:are_all_predecessors_enabled()
    if not self:is_enabled() then
        return false
    end
    if self.parent then
        return self.parent:are_all_predecessors_enabled()
    else
        return true
    end
end

---@param value boolean
function Control:set_visible(value)
    self._is_visable = value
end

---@return boolean
function Control:is_visible()
    return self._is_enabled and self._is_visable
end

function Control:draw()
    local w, h = love.graphics:getDimensions()
    for _, child in ipairs(self.children) do
        local min_x, min_y, max_x, max_y = child._global_aabb:get_bounds()
        if child:is_visible() and min_x < w and max_x >= 0 and min_y < h and max_y >= 0 then
            child:draw()
        end
    end
end

---@param parent Control|nil
---@param width number|nil
---@param height number|nil
function Control:init(parent, width, height)
    assert(not parent or is_instance_of(self, Control))
    self._is_enabled = true
    self._is_visable = true

    self._local_transform = love.math.newTransform()
    self.global_transform = love.math.newTransform()
    self:_reset_local_transform()
    self.size = {
        width or 0,
        height or 0
    }
    self._global_aabb = Aabb()

    Tree.init(self, parent)
end

return Control

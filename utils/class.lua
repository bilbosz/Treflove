require("utils.table")

local select = select

---@class Object
local Object = {}

---@alias Class Object|fun(...): Object A class table: the language server types it as its class, joined by the constructor overload the plugin adds

---@alias Destructor fun(self: Object, reason: lifetime.Reason) A class's `release`, run by lua-lifetime when the instance dies

---@class ClassMetatable
---@field __index table<string, any> The merged methods of the class and its bases
---@field __newindex table<string, any>
---@field __call fun(cls: Class, ...): Object
---@field name string
---@field bases Class[] The class and every class it derives from

---@class ObjectMetatable
---@field __index table<string, any>
---@field class Class
---@field __lifetime_destroy fun(obj: Object, reason: lifetime.Reason) Forwards to the class's `release`

---@type lifetime|nil The runtime, required on first use
local lifetime = nil

---@generic O
---@param self O
---@param ... lifetime.Anchor The anchors, as for `lifetime.attach`
---@return O
function Object.attach_lifetime(self, ...)
    if not lifetime then
        lifetime = require("lifetime")
    end
    return lifetime.attach(self, ...)
end

---@param cls Class
---@return ClassMetatable
local function _get_class_metatable(cls)
    return getmetatable(cls) --[[@as ClassMetatable]]
end

---@param obj Object
---@return ObjectMetatable
local function _get_object_metatable(obj)
    return getmetatable(obj) --[[@as ObjectMetatable]]
end

---@param self table Class table under construction
---@param ... Class Base class tables
---@return table<string, any> Merged method index table
local function _create_index(self, ...)
    local idx = {}
    table.merge(idx, Object)
    for i = select("#", ...), 1, -1 do
        table.merge(idx, _get_class_metatable(select(i, ...)).__index)
    end
    table.merge(idx, self)
    return idx
end

---@param self table Class table under construction
---@param ... Class Base class tables
---@return Class[] All classes `self` derives from, including itself
local function _create_bases(self, ...)
    local bases = {
        self
    }
    for i = 1, select("#", ...) do
        table.merge_array(bases, _get_class_metatable(select(i, ...)).bases)
    end
    return bases
end

---@param cls Class
---@param base Class Potential base class table
---@return boolean
local function _is_instance_of(cls, base)
    return table.find_table_key(_get_class_metatable(cls).bases, base) ~= nil
end

---@param name string Class name
---@param ... Class Class bases
---@return table New class table
function class(name, ...)
    local class = {}
    assert(name)
    for i = 1, select("#", ...) do
        assert(select(i, ...), string.format("Inherited class number %i of %s is not initialized yet", i, name))
    end

    local index = _create_index(class, ...)
    ---@type ObjectMetatable
    local obj_mt = {
        __index = index,
        class = class,
        ---@param obj table
        ---@param reason lifetime.Reason
        __lifetime_destroy = function(obj, reason)
            ---@type Destructor|nil
            local release = obj.release
            if release then
                release(obj, reason)
            end
        end
    }

    local class_metatable = {
        __index = index,
        __newindex = index,
        __call = function(_, ...)
            local obj = {}
            setmetatable(obj, obj_mt)
            if obj.init then
                obj:init(...)
            end
            return obj
        end,
        name = name,
        bases = _create_bases(class, ...)
    }

    return setmetatable(class, class_metatable)
end

---@generic O
---@param obj O
---@return Class
function get_class_of(obj)
    return _get_object_metatable(obj).class
end

---@generic O
---@param obj O
---@return string
function get_class_name_of(obj)
    return _get_class_metatable(get_class_of(obj)).name
end

---@param obj Object
---@param cls Class
---@return boolean
function is_instance_of(obj, cls)
    return _is_instance_of(get_class_of(obj), cls)
end

---@param obj any
---@param typ type|Class The name `type()` gives, or a class table
function assert_type(obj, typ)
    local msg = "Expected %s got %s"
    if type(typ) == "string" then
        assert(type(obj) == typ, string.format(msg, typ, type(obj)))
    elseif type(typ) == "table" then
        local class_mt = _get_class_metatable(typ)
        assert(class_mt)
        local class_name = class_mt.name
        assert(class_name)
        if getmetatable(obj) and get_class_of(obj) then
            assert(is_instance_of(obj, typ), string.format(msg, class_name, get_class_name_of(obj)))
        else
            assert_unreachable(string.format(msg, class_name, type(obj)))
        end
    else
        assert_unreachable()
    end
end

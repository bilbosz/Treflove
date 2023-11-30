require("utils.table")

local select = select

local function _create_index(self, ...)
    local idx = {}
    for i = select("#", ...), 1, -1 do
        table.merge(idx, getmetatable(select(i, ...)).__index)
    end
    table.merge(idx, self)
    return idx
end

local function _create_bases(self, ...)
    local bases = {
        self
    }
    for i = 1, select("#", ...) do
        table.merge_array(bases, getmetatable(select(i, ...)).bases)
    end
    return bases
end

local function _is_instance_of(cls, base)
    return table.find_table_key(getmetatable(cls).bases, base) ~= nil
end

---@param name string Class name
---@param ... table Class bases
function class(name, ...)
    local class = {}
    assert(name)
    for i = 1, select("#", ...) do
        assert(select(i, ...), string.format("Inherited class number %i of %s is not initialized yet", i, name))
    end

    local index = _create_index(class, ...)
    local objMt = {
        __index = index,
        class = class
    }

    local class_metatable = {
        __index = index,
        __newindex = index,
        __call = function(_, ...)
            local obj = {}
            setmetatable(obj, objMt)
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

---@param obj table
---@return table
function get_class_of(obj)
    return getmetatable(obj).class
end

---@param obj table
---@return string
function get_class_name_of(obj)
    return getmetatable(get_class_of(obj)).name
end

---@param obj table
---@param cls table
---@return boolean
function is_instance_of(obj, cls)
    return _is_instance_of(get_class_of(obj), cls)
end

---@param obj any
---@param typ string|table
---@return void
function assert_type(obj, typ)
    local msg = "Expected %s got %s"
    if type(typ) == "string" then
        assert(type(obj) == typ, string.format(msg, typ, type(obj)))
    elseif type(typ) == "table" then
        local classMt = getmetatable(typ)
        assert(classMt)
        local className = classMt.name
        assert(className)
        if getmetatable(obj) and get_class_of(obj) then
            assert(is_instance_of(obj, typ), string.format(msg, className, get_class_name_of(obj)))
        else
            assert_unreachable(string.format(msg, className, type(obj)))
        end
    else
        assert_unreachable()
    end
end


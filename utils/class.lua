local function CreateIndex(self, ...)
    local idx = {}
    for i = select("#", ...), 1, -1 do
        table.merge(idx, getmetatable(select(i, ...)).__index)
    end
    table.merge(idx, self)
    return idx
end

function MakeClassOf(self, ...)
    local name = GetGlobalName(self)
    assert(name)
    for i = 1, select("#", ...) do
        assert(select(i, ...), string.format("Inherited class no. %i of %s is not initialized yet", i, name))
    end
    local objMt = {
        __index = CreateIndex(self, ...),
        class = self
    }
    local mt = {
        __index = objMt.__index,
        __call = function(self, ...)
            local obj = {}
            setmetatable(obj, objMt)
            if obj.Init then
                obj:Init(...)
            end
            return obj
        end,
        name = name,
        bases = {
            ...
        }
    }
    setmetatable(self, mt)
end

function GetClassOf(obj)
    return getmetatable(obj).class
end

function GetClassNameOf(obj)
    return getmetatable(GetClassOf(obj)).name
end

local function IsClassInstanceOf(cls, base)
    if cls == base then
        return true
    end
    for _, v in ipairs(getmetatable(cls).bases) do
        if IsClassInstanceOf(v, base) then
            return true
        end
    end
    return false
end

function IsInstanceOf(obj, cls)
    return IsClassInstanceOf(GetClassOf(obj), cls)
end

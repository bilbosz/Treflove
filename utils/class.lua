local function CreateIndex(self, ...)
    local idx = {}
    for i = select("#", ...), 1, -1 do
        table.merge(idx, getmetatable(select(i, ...)).__index)
    end
    table.merge(idx, self)
    return idx
end

local function CreateBases(self, ...)
    local bases = {
        self
    }
    for i = 1, select("#", ...) do
        table.mergearray(bases, getmetatable(select(i, ...)).bases)
    end
    return bases
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
        bases = CreateBases(self, ...)
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
    return table.findkey(getmetatable(cls).bases, base) ~= nil
end

function IsInstanceOf(obj, cls)
    return IsClassInstanceOf(GetClassOf(obj), cls)
end

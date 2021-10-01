local function CreateIndex(self, ...)
    local idx = {}
    for i = select("#", ...), 1, -1 do
        table.merge(idx, getmetatable(select(i, ...)).__index)
    end
    table.merge(idx, self)
    return idx
end

local function GetGlobalName(obj)
    for k, v in pairs(_G) do
        if v == obj then
            return k
        end
    end
end

function MakeClassOf(self, ...)
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
        classname = GetGlobalName(self)
    }
    setmetatable(self, mt)
end

function MakeModelOf(self, ...)
    local objMt = {
        __index = CreateIndex(self, ...),
        class = self
    }
    local mt = {
        __index = objMt.__index,
        __call = function(self, data, ...)
            local obj = {
                data = data
            }
            setmetatable(obj, objMt)
            if obj.Init then
                obj:Init(...)
            end
            return obj
        end,
        classname = GetGlobalName(self)
    }
    setmetatable(self, mt)
end

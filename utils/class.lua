local function CreateIndex(self, ...)
    local idx = {}
    for i = select("#", ...), 1, -1 do
        table.merge(idx, getmetatable(select(i, ...)).__index)
    end
    table.merge(idx, self)
    return idx
end

function MakeClassOf(self, ...)
    local objMt = {
        __index = CreateIndex(self, ...)
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
        end
    }
    setmetatable(self, mt)
end

function MakeInjectorOf(self, ...)
    local objMt = {
        __index = CreateIndex(self, ...)
    }
    local mt = {
        __index = objMt.__index,
        __call = function(self, inj, ...)
            setmetatable(inj, objMt)
            if inj.Init then
                inj:Init(...)
            end
            return inj
        end
    }
    setmetatable(self, mt)
end

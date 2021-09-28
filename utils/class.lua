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
        __call = function(...)
            local obj = {}
            setmetatable(obj, objMt)
            if obj.Init then
                obj:Init(select(2, ...))
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
        __call = function(inj, ...)
            setmetatable(inj, objMt)
            if inj.Init then
                inj:Init(select(3, ...))
            end
            return inj
        end
    }
    setmetatable(self, mt)
end

local function CreateIndex(self, ...)
    local n = select("#", ...)
    local index = {}
    for i = n, 2, -1  do
        local base = select(i, ...)
        assert(type(base) == "table")
        table.merge(index, getmetatable(base).__index)
    end
    table.merge(index, self)
    return index
end

function MakeClass(...)
    local self = ...
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
    return self
end
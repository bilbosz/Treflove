Model = {}

function Model:GetData()
    return self.data
end

function MakeModelOf(self, ...)
    local name = GetGlobalName(self)
    assert(name)
    for i = 1, select("#", ...) do
        assert(select(i, ...), string.format("Inherited class no. %i of %s is not initialized yet", i, name))
    end
    local objMt = {
        __index = CreateIndex(self, Model, ...),
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
        name = name
    }
    setmetatable(self, mt)
    if self.ClassInit then
        self:ClassInit(...)
    end
end

MakeClassOf(Model)

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
        name = name
    }
    setmetatable(self, mt)
    if self.ClassInit then
        self:ClassInit(...)
    end
end

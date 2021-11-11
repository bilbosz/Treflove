if debug then
    function MakeClassOf(self, ...)
        local name = GetGlobalName(self)
        assert(name)
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
            name = GetGlobalName(self)
        }
        setmetatable(self, mt)
        if self.ClassInit then
            self:ClassInit(...)
        end
    end
else
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
        if self.ClassInit then
            self:ClassInit(...)
        end
    end
end

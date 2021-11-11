Model = {}

function Model:GetData()
    return self.data
end

if debug then
    function MakeModelOf(self, ...)
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
            name = GetGlobalName(self)
        }
        setmetatable(self, mt)
        if self.ClassInit then
            self:ClassInit(...)
        end
    end
else
    function MakeModelOf(self, ...)
        local objMt = {
            __index = CreateIndex(self, Model, ...)
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
            end
        }
        setmetatable(self, mt)
        if self.ClassInit then
            self:ClassInit(...)
        end
    end
end

MakeClassOf(Model)

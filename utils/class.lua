local function CreateIndex(self, ...)
    local idx = {}
    for i = select("#", ...), 1, -1 do
        table.merge(idx, getmetatable(select(i, ...)).__index)
    end
    table.merge(idx, self)
    return idx
end

if debug then
    local function GetGlobalName(obj)
        for k, v in pairs(_G) do
            if v == obj then
                return k
            end
        end
    end

    local objects = {}
    setmetatable(objects, {
        __mode = "k"
    })

    function ReloadObjects()
        for obj in pairs(objects) do
            local objMt = getmetatable(obj)
            local class = objMt.class
            local mt = getmetatable(class)
            local name = mt.name
            local newClass = _G[name]
            local newMt = getmetatable(newClass)
            objMt.__index = newMt.__index
            objMt.class = newClass
        end
    end

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
                objects[obj] = true
                if obj.Init then
                    obj:Init(...)
                end
                return obj
            end,
            name = GetGlobalName(self)
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
                objects[obj] = true
                if obj.Init then
                    obj:Init(...)
                end
                return obj
            end,
            name = GetGlobalName(self)
        }
        setmetatable(self, mt)
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
    end

    function MakeModelOf(self, ...)
        local objMt = {
            __index = CreateIndex(self, ...)
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
    end
end

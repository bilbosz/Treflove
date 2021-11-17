EventManager = {}

function EventManager:Init(listenerClass)
    self.methods = {}
    self.listenerClass = listenerClass
    self.listenerIndex = getmetatable(self.listenerClass).__index
    local mt = {
        __mode = "k"
    }
    for _, method in pairs(self.listenerIndex) do
        self.methods[method] = {}
        setmetatable(self.methods[method], mt)
    end
end

function EventManager:RegisterListener(listener)
    for methodName, classMethod in pairs(self.listenerIndex) do
        local listenerMethod = listener[methodName]
        assert(listenerMethod)
        self.methods[classMethod][listener] = listenerMethod
    end
end

function EventManager:UnregisterListener(listener)
    for _, method in pairs(self.listenerIndex) do
        self.methods[method][listener] = nil
    end
end

function EventManager:InvokeEvent(method, ...)
    for listener, listenerMethod in pairs(self.methods[method]) do
        listenerMethod(listener, ...)
    end
end

MakeClassOf(EventManager)

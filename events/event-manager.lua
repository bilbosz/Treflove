EventManager = {}

function EventManager:Init(listenerClass)
    self.methods = {}
    self.listenerClass = listenerClass
    local mt = {
        __mode = "k"
    }
    for _, method in pairs(self.listenerClass) do
        self.methods[method] = {}
        setmetatable(self.methods[method], mt)
    end
end

function EventManager:RegisterListener(listener)
    for methodName, classMethod in pairs(self.listenerClass) do
        local listenerMethod = listener[methodName]
        self.methods[classMethod][listener] = listenerMethod
    end
end

function EventManager:UnregisterListener(listener)
    for _, method in pairs(self.listenerClass) do
        self.methods[method][listener] = nil
    end
end

function EventManager:InvokeEvent(method, ...)
    for listener, listenerMethod in pairs(self.methods[method]) do
        if listenerMethod then
            listenerMethod(listener, ...)
        end
    end
end

MakeClassOf(EventManager)

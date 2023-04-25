EventManager = {}

local function HandleRegister(self, listener)
    for methodName, classMethod in pairs(self.listenerClass) do
        if self.methods[classMethod] then
            local listenerMethod = listener[methodName]
            self.methods[classMethod][listener] = listenerMethod
        end
    end
end

local function HandleUnregister(self, listener)
    for _, classMethod in pairs(self.listenerClass) do
        if self.methods[classMethod] then
            self.methods[classMethod][listener] = nil
        end
    end
end

local function IsListenerMethodName(methodName)
    local prefix = string.sub(methodName, 1, 2)
    local third = string.sub(methodName, 3, 3)
    return prefix == "On" and third and third == string.upper(third)
end

function EventManager:Init(listenerClass)
    self.methods = {}
    self.listenerClass = listenerClass
    local mt = {
        __mode = "k"
    }
    for methodName, method in pairs(self.listenerClass) do
        if IsListenerMethodName(methodName) then 
            self.methods[method] = {}
            setmetatable(self.methods[method], mt)
        end
    end
    -- lock is turned on only for invoking
    self.lock = false
    -- adding is delayed
    self.toAdd = {}
    -- removing is immediate
    self.toRemove = {}
end

function EventManager:RegisterListener(listener)
    if self.lock then
        self.toAdd[listener] = true
        return
    end
    HandleRegister(self, listener)
end

function EventManager:UnregisterListener(listener)
    if self.lock then
        self.toRemove[listener] = true
        return
    end
    HandleUnregister(self, listener)
end

function EventManager:HandlePostponed()
    assert(not self.lock)
    for listener in pairs(self.toRemove) do
        HandleUnregister(self, listener)
    end
    self.toRemove = {}

    for listener in pairs(self.toAdd) do
        HandleRegister(self, listener)
    end
    self.toAdd = {}
end

function EventManager:InvokeEvent(method, ...)
    assert(not self.lock)
    self.lock = true
    for listener, listenerMethod in pairs(self.methods[method]) do
        if not self.toRemove[listener] then
            listenerMethod(listener, ...)
        end
    end
    self.lock = false
    self:HandlePostponed()
end

MakeClassOf(EventManager)

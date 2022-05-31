UpdateEventListener = {}

function UpdateEventListener:OnUpdate(dt)
    abstract()
end

MakeClassOf(UpdateEventListener)

UpdateEventManager = {}

function UpdateEventManager:Init()
    EventManager.Init(self, UpdateEventListener)
end

MakeClassOf(UpdateEventManager, EventManager)

UpdateEventListener = {}

function UpdateEventListener:OnUpdate(dt)
    assert(false, "Abstract")
end

MakeClassOf(UpdateEventListener)

UpdateEventManager = {}

function UpdateEventManager:Init()
    EventManager.Init(self, UpdateEventListener)
end

MakeClassOf(UpdateEventManager, EventManager)

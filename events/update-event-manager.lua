UpdateEventManager = {}

function UpdateEventManager:Init()
    EventManager.Init(self, UpdateEventListener)
end

MakeClassOf(UpdateEventManager, EventManager)

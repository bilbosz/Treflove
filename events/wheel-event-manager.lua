WheelEventManager = {}

function WheelEventManager:Init()
    EventManager.Init(self, WheelEventListener)
end

MakeClassOf(WheelEventManager, EventManager)

WheelEventListener = {}

function WheelEventListener:OnWheelMoved(x, y)
    abstract()
end

MakeClassOf(WheelEventListener)

WheelEventManager = {}

function WheelEventManager:Init()
    EventManager.Init(self, WheelEventListener)
end

MakeClassOf(WheelEventManager, EventManager)

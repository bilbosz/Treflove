WheelEventListener = {}

function WheelEventListener:OnWheelMoved(x, y)
    assert(false, "Abstract")
end

MakeClassOf(WheelEventListener)

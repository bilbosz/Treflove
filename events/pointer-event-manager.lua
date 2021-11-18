PointerEventManager = {}

function PointerEventManager:Init()
    EventManager.Init(self, PointerEventListener)
    self.downId = nil
end

function PointerEventManager:PointerDown(x, y, id)
    self.downId = id
    self:InvokeEvent(PointerEventListener.OnPointerDown, x, y, id)
end

function PointerEventManager:PointerUp(x, y, id)
    self:InvokeEvent(PointerEventListener.OnPointerUp, x, y, id)
    self.downId = nil
end

function PointerEventManager:PointerMove(x, y, id)
    self:InvokeEvent(PointerEventListener.OnPointerMove, x, y, id or self.downId)
end

MakeClassOf(PointerEventManager, EventManager)

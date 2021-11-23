PointerEventListener = {}

function PointerEventListener:Init(receiveThrough)
    self.receiveThrough = receiveThrough
end

function PointerEventListener:OnPointerDown(x, y, id)

end

function PointerEventListener:OnPointerUp(x, y, id)

end

function PointerEventListener:OnPointerMove(x, y, id)

end

MakeClassOf(PointerEventListener, Control)

PointerEventManager = {}

local function GetListenerList(ctrl, listeners, x, y, list)
    local minX, minY, maxX, maxY = ctrl:GetGlobalAabb()
    if not ctrl:IsVisible() or x < minX or x > maxX or y < minY or y > maxY then
        return nil
    end
    if listeners[ctrl] then
        table.insert(list, ctrl)
    end
    for _, child in ipairs(ctrl:GetChildren()) do
        GetListenerList(child, listeners, x, y, list)
    end
end

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

function PointerEventManager:InvokeEvent(method, x, y, id)
    local listeners = self.methods[method]
    local list = {}
    GetListenerList(app.root, listeners, x, y, list)
    local topToBeCalled = true
    for i = #list, 1, -1 do
        local ctrl = list[i]
        local listener = listeners[ctrl]
        if topToBeCalled then
            local passThrough = listener(ctrl, x, y, id)
            if not passThrough then
                topToBeCalled = false
            end
        elseif ctrl.receiveThrough then
            listener(ctrl, x, y, id)
        end
    end
end

MakeClassOf(PointerEventManager, EventManager)

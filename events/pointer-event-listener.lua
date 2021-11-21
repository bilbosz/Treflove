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

function PointerEventListener:OnPointerClick(x, y, id)

end

function PointerEventListener:OnPointerDoubleClick(x, y, id)

end

MakeClassOf(PointerEventListener, Control)

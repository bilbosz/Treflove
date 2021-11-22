ButtonEventListener = {}

function ButtonEventListener:Init()
    self.selected = false
    self.hovered = false
end

function ButtonEventListener:OnPointerEnter()
    self.hovered = true
end

function ButtonEventListener:OnPointerLeave()
    self.hovered = false
end

function ButtonEventListener:OnUnselect()
    self.selected = false
end

function ButtonEventListener:OnSelect()
    self.selected = true
end

function ButtonEventListener:OnClick()

end

function ButtonEventListener:IsSelected()
    return self.selected
end

function ButtonEventListener:IsHovered()
    return self.hovered
end

MakeClassOf(ButtonEventListener, Control)

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

ButtonEventManager = {}

local function GetListenerInternal(ctrl, listeners, x, y)
    local minX, minY, maxX, maxY = ctrl:GetGlobalAabb()
    if x < minX or x > maxX or y < minY or y > maxY then
        return nil
    end
    local top
    if listeners[ctrl] then
        top = ctrl
    end
    for _, child in ipairs(ctrl:GetChildren()) do
        if child:IsEnabled() then
            top = top or GetListenerInternal(child, listeners, x, y)
        end
    end
    return top
end

local function GetListener(self, x, y)
    return GetListenerInternal(app.root, select(2, next(self.methods)), x, y)
end

function ButtonEventManager:Init()
    EventManager.Init(self, ButtonEventListener)
    self.hover = nil
    self.selection = nil
end

function ButtonEventManager:PointerDown(x, y, id)
    assert(not self.selection)
    local selection = GetListener(self, x, y)
    if not selection then
        return
    end
    self.selection = selection
    selection:OnSelect()
end

function ButtonEventManager:PointerUp(x, y, id)
    local selection = self.selection
    local top = GetListener(self, x, y)
    if selection and selection == top then
        selection:OnUnselect()
        selection:OnClick()
    end
    self.selection = nil
end

function ButtonEventManager:PointerMove(x, y, id)
    local top = GetListener(self, x, y)
    local selection = self.selection
    local hover = self.hover
    if selection then
        if selection ~= top then
            selection:OnUnselect()
        end
        if selection == top and selection ~= hover then
            selection:OnSelect()
        end
    end
    if hover ~= top then
        if hover then
            hover:OnPointerLeave()
        end
        if top then
            top:OnPointerEnter()
        end
    end
    self.hover = top
end

MakeClassOf(ButtonEventManager, EventManager)

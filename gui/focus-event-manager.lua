FocusEventManager = {}

local function NotifyListeners(self)
    if self.prevFocus == self.currentFocus then
        return
    end
    local oldItem = self.focusItems[self.prevFocus]
    if oldItem then
        oldItem:OnFocusLost()
    end
    local newItem = self.focusItems[self.currentFocus]
    if newItem then
        newItem:OnFocus()
    end
end

function FocusEventManager:Init()
    EventManager.Init(self, FocusEventListener)
    self.focusItems = {}
    self.prevFocus = nil
    self.currentFocus = nil
end

function FocusEventManager:RegisterListener(listener)
    EventManager.RegisterListener(self, listener)
    table.insert(self.focusItems, listener)
end

function FocusEventManager:UnregisterListener(listener)
    EventManager.UnregisterListener(self, listener)
    local found
    for i, v in ipairs(self.focusItems) do
        if v == listener then
            found = i
            break
        end
    end
    if found then
        table.remove(self.focusItems, found)
        if found == self.currentFocus then
            self.currentFocus = nil
        end
        if found == self.prevFocus then
            self.prevFocus = nil
        end
    end
end

function FocusEventManager:KeyPressed(key)
    if key == "tab" then
        self.prevFocus = self.currentFocus
        local i = self.currentFocus or 1
        local n = #self.focusItems
        if n == 0 then
            return
        end
        if love.keyboard.isDown("lshift") then
            i = i - 1
        else
            i = i + 1
        end
        i = (i - 1 + n) % n + 1
        self.currentFocus = i
        NotifyListeners(self)
    end
end

function FocusEventManager:Focus(item)
    local found
    for i, v in ipairs(self.focusItems) do
        if v == item then
            found = i
            break
        end
    end
    assert(found)
    self.prevFocus = self.currentFocus
    self.currentFocus = found
    NotifyListeners(self)
end

MakeClassOf(FocusEventManager, EventManager)

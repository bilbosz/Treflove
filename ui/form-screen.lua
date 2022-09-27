FormScreen = {}

local function NotifyListeners(self)
    if self.prevFocus == self.currentFocus then
        return
    end
    local oldItem = self.inputs[self.prevFocus]
    if oldItem then
        oldItem:OnFocusLost()
    end
    local newItem = self.inputs[self.currentFocus]
    if newItem then
        newItem:OnFocus()
    end
end

function FormScreen:Init()
    Screen.Init(self)
    KeyboardEventListener.Init(self, true)
    self.inputs = {}
    self.prevFocus = nil
    self.currentFocus = nil
    self.isShowed = false
end

function FormScreen:Show(...)
    Screen.Show(self, ...)
    for _, input in ipairs(self.inputs) do
        input:OnScreenShow()
    end
    app.keyboardManager:RegisterListener(self)
    self.isShowed = true
end

function FormScreen:Hide()
    self.isShowed = false
    app.keyboardManager:UnregisterListener(self)
    for _, input in ipairs(self.inputs) do
        input:OnScreenHide()
    end
    Screen.Hide(self)
end

function FormScreen:IsShowed()
    return self.isShowed
end

function FormScreen:OnKeyPressed(key)
    if key == "tab" then
        self.prevFocus = self.currentFocus
        local i = self.currentFocus or 0
        local n = #self.inputs
        if n == 0 then
            return
        end
        if app.keyboardManager:IsKeyDown("lshift") then
            i = i - 1
        else
            i = i + 1
        end
        i = (i - 1 + n) % n + 1
        self.currentFocus = i
        NotifyListeners(self)
    end
end

function FormScreen:AddInput(input)
    assert_type(input, Input)
    table.insert(self.inputs, input)
    self.currentFocus = nil
end

function FormScreen:RemoveInput(input)
    assert_type(input, Input)
    local found
    for i, v in ipairs(self.inputs) do
        if v == input then
            found = i
            break
        end
    end
    assert(found)
    table.remove(self.inputs, found)
    if found == self.currentFocus then
        self.currentFocus = nil
    end
    if found == self.prevFocus then
        self.prevFocus = nil
    end
end

function FormScreen:Focus(input)
    assert_type(input, Input)
    local found
    for i, v in ipairs(self.inputs) do
        if v == input then
            found = i
            break
        end
    end
    assert(found)
    self.prevFocus = self.currentFocus
    self.currentFocus = found
    NotifyListeners(self)
end

function FormScreen:RemoveAllInputs()
    self.inputs = {}
    self.prevFocus = nil
    self.currentFocus = nil
end

MakeClassOf(FormScreen, Screen, KeyboardEventListener)

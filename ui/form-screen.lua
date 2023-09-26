FormScreen = {}

local function NotifyListeners(self)
    if self.prevFocus == self.focus then
        return
    end
    local oldItem = self.inputs[self.prevFocus]
    if oldItem then
        oldItem:OnFocusLost()
    end
    local newItem = self.inputs[self.focus]
    if newItem then
        newItem:OnFocus()
    end
end

local function AdvanceFocus(self, d)
    assert(d == 1 or d == -1)
    local inputs = self.inputs
    self.prevFocus = self.focus

    local n = #inputs
    if n == 0 then
        return
    end

    local count = 0
    for _, v in ipairs(inputs) do
        if not v:IsReadOnly() then
            count = count + 1
        end
    end
    if count == 0 then
        return
    end

    local i = self.focus or 0
    while true do
        i = (i + d - 1 + n) % n + 1
        if inputs[i]:AllPredecessorsEnabled() and not inputs[i]:IsReadOnly() then
            break
        end
    end
    self.focus = i
end

function FormScreen:Init()
    Screen.Init(self)
    KeyboardEventListener.Init(self, true)
    self.inputs = {}
    self.prevFocus = nil
    self.focus = nil
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
        if app.keyboardManager:IsKeyDown("lshift") then
            AdvanceFocus(self, -1)
        else
            AdvanceFocus(self, 1)
        end
        NotifyListeners(self)
    end
end

function FormScreen:AddInput(input)
    assert_type(input, Input)
    table.insert(self.inputs, input)
end

function FormScreen:RemoveInput(input)
    assert_type(input, Input)
    local found = table.findidx(self.inputs, input)
    assert(found)
    table.remove(self.inputs, found)
    if found == self.focus then
        self.focus = nil
    end
    if found == self.prevFocus then
        self.prevFocus = nil
    end
end

function FormScreen:ReadOnlyChange(input)
    assert_type(input, Input)
    local found = table.findidx(self.inputs, input)
    assert(found)
    if found == self.focus then
        AdvanceFocus(self, 1)
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
    self.prevFocus = self.focus
    self.focus = found
    NotifyListeners(self)
end

function FormScreen:RemoveAllInputs()
    self.inputs = {}
    self.prevFocus = nil
    self.focus = nil
end

MakeClassOf(FormScreen, Screen, KeyboardEventListener)

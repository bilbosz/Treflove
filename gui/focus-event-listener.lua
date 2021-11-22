FocusEventListener = {}

function FocusEventListener:Init()
    self.isFocused = false
end

function FocusEventListener:OnFocus()
    self.isFocused = true
end

function FocusEventListener:OnFocusLost()
    self.isFocused = false
end

function FocusEventListener:IsFocused()
    return self.isFocused
end

MakeClassOf(FocusEventListener)

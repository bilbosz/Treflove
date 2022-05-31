Input = {}

function Input:Init()
    self.isFocused = false
end

function Input:OnScreenShow()
    abstract()
end

function Input:OnScreenHide()
    abstract()
end

function Input:OnFocus()
    self.isFocused = true
end

function Input:OnFocusLost()
    self.isFocused = false
end

function Input:IsFocused()
    return self.isFocused
end

MakeClassOf(Input)

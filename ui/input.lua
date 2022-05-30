Input = {}

function Input:Init()
    self.isFocused = false
end

function Input:OnScreenShow()
    assert(false)
end

function Input:OnScreenHide()
    assert(false)
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

Input = {}

function Input:Init(formScreen)
    assert_type(formScreen, FormScreen)
    self.formScreen = formScreen
    self.isFocused = false
    self.isReadOnly = false
end

function Input:GetFormScreen()
    return self.formScreen
end

function Input:SetReadOnly(value)
    if self.isReadOnly ~= value then
        self.isReadOnly = value
        if value then
            self.formScreen:RemoveInput(self)
        else
            self.formScreen:AddInput(self)
        end
    end
end

function Input:IsReadOnly()
    return self.isReadOnly
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

Input = {}

function Input:Init(formScreen)
    assert_type(formScreen, FormScreen)
    self.formScreen = formScreen
    self.isFocused = false
    self.isReadOnly = false
    formScreen:AddInput(self)
    if formScreen:IsShowed() then
        self:OnScreenShow()
    end
end

function Input:GetFormScreen()
    return self.formScreen
end

function Input:SetReadOnly(value)
    if self.isReadOnly ~= value then
        self.isReadOnly = value
        self:OnReadOnlyChange()
    end
end

function Input:IsReadOnly()
    return self.isReadOnly
end

function Input:OnReadOnlyChange()
    self.formScreen:ReadOnlyChange(self)
end

function Input:OnScreenShow()
    app.buttonEventManager:RegisterListener(self)
end

function Input:OnScreenHide()
    app.buttonEventManager:UnregisterListener(self)
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

TextButton = {}

local function UpdateTextColor(self)
    self:SetColor((self:IsFocused() or self:IsSelected()) and Consts.BUTTON_SELECT_COLOR or self:IsHovered() and Consts.BUTTON_HOVER_COLOR or Consts.BUTTON_NORMAL_COLOR)
end

function TextButton:Init(parent, formScreen, text, action)
    Text.Init(self, parent, text, Consts.BUTTON_NORMAL_COLOR)
    ButtonEventListener.Init(self)
    Input.Init(self, formScreen)
    KeyboardEventListener.Init(self, true)
    self.action = action
    self.isHover = false
    self.text = text
end

function TextButton:OnScreenShow()
    Input.OnScreenShow(self)
    if self:IsFocused() then
        app.keyboardManager:RegisterListener(self)
    end
end

function TextButton:OnScreenHide()
    Input.OnScreenHide(self)
    app.keyboardManager:UnregisterListener(self)
end

function TextButton:OnFocus()
    Input.OnFocus(self)
    UpdateTextColor(self)
    app.keyboardManager:RegisterListener(self)
end

function TextButton:OnFocusLost()
    app.keyboardManager:UnregisterListener(self)
    Input.OnFocusLost(self)
    UpdateTextColor(self)
end

function TextButton:OnSelect()
    ButtonEventListener.OnSelect(self)
    UpdateTextColor(self)
end

function TextButton:OnUnselect()
    ButtonEventListener.OnUnselect(self)
    UpdateTextColor(self)
end

function TextButton:OnPointerEnter()
    ButtonEventListener.OnPointerEnter(self)
    UpdateTextColor(self)
end

function TextButton:OnPointerLeave()
    ButtonEventListener.OnPointerLeave(self)
    UpdateTextColor(self)
end

function TextButton:OnClick()
    ButtonEventListener.OnClick(self)
    self.action()
end

function TextButton:OnKeyPressed(key)
    if key == "return" then
        self.action()
    end
end

MakeClassOf(TextButton, Text, ButtonEventListener, Input, KeyboardEventListener)

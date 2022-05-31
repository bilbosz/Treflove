TextButton = {}

local function UpdateTextColor(self)
    self:SetColor((self:IsFocused() or self:IsSelected()) and Consts.BUTTON_SELECT_COLOR or self:IsHovered() and Consts.BUTTON_HOVER_COLOR or Consts.BUTTON_NORMAL_COLOR)
end

function TextButton:Init(parent, screen, text, action)
    Text.Init(self, parent, text, Consts.BUTTON_NORMAL_COLOR)
    ButtonEventListener.Init(self)
    KeyboardEventListener.Init(self, true)
    self.screen = screen
    self.action = action
    self.isHover = false
    screen:AddInput(self)
end

function TextButton:OnScreenShow()
    app.buttonEventManager:RegisterListener(self)
    if self:IsFocused() then
        app.keyboardManager:RegisterListener(self)
    end
end

function TextButton:OnScreenHide()
    app.buttonEventManager:UnregisterListener(self)
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

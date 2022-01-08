TextButton = {}

local function UpdateTextColor(self)
    self:SetColor(self:IsSelected() and Consts.BUTTON_SELECT_COLOR or self:IsHovered() and Consts.BUTTON_HOVER_COLOR or Consts.BUTTON_NORMAL_COLOR)
end

function TextButton:Init(parent, text, action)
    Text.Init(self, parent, text, Consts.BUTTON_NORMAL_COLOR)
    ButtonEventListener.Init(self)
    self.action = action
    self.isHover = false
    app.buttonEventManager:RegisterListener(self)
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

MakeClassOf(TextButton, Text, ButtonEventListener)

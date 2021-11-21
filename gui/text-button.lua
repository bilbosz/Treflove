TextButton = {}

function TextButton:Init(parent, text, action)
    Text.Init(self, parent, text, Consts.BUTTON_NORMAL_COLOR)
    ButtonEventListener.Init(self)
    self.action = action
    app.buttonEventManager:RegisterListener(self)
end

function TextButton:OnSelect()
    self:SetColor(Consts.BUTTON_SELECT_COLOR)
end

function TextButton:OnUnselect()
    self:SetColor(Consts.BUTTON_NORMAL_COLOR)
end

function TextButton:OnPointerEnter()
    self:SetColor(Consts.BUTTON_HOVER_COLOR)
end

function TextButton:OnPointerLeave()
    self:SetColor(Consts.BUTTON_NORMAL_COLOR)
end

function TextButton:OnClick()
    self.action()
end

MakeClassOf(TextButton, Text, ButtonEventListener)

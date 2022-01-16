MenuTextButton = {}

function MenuTextButton:Init(label, callback)
    MenuEntry.Init(self)
    self.label = label
    self.callback = callback
end

function MenuTextButton:CreateControl(parent)
    local ctrl = Control(parent)
    self.control = ctrl
    ctrl:SetScale(Consts.MENU_BUTTON_SCALE)

    local text = TextButton(ctrl, self.label, self.callback)
    local w = text:GetSize()
    text:SetOrigin(w * 0.5, 0)

    return ctrl
end

MakeClassOf(MenuTextButton, MenuEntry)

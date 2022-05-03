MenuTextButton = {}

function MenuTextButton:Init(label, cb)
    MenuEntry.Init(self)
    self.label = label
    self.cb = cb
end

function MenuTextButton:CreateControl(parent)
    local ctrl = Control(parent)
    self.control = ctrl
    ctrl:SetScale(Consts.MENU_BUTTON_SCALE)

    local text = TextButton(ctrl, self.label, self.cb)
    local w = text:GetSize()
    text:SetOrigin(w * 0.5, 0)

    return ctrl
end

MakeClassOf(MenuTextButton, MenuEntry)

MenuButton = {}

function MenuButton:Init(label, callback)
    MenuEntry.Init(self)
    self.label = label
    self.callback = callback
end

function MenuButton:CreateControl(anchor)
    local ctrl = Control(anchor)

    local text = TextButton(ctrl, self.label, self.callback)
    local w, h = text:GetSize()
    text:SetOrigin(w * 0.5, h * 0.5)

    local s = Consts.MENU_BUTTON_SCALE
    h = h + 2 * Consts.MENU_BUTTON_PADDING
    ctrl:SetSize(w, h)
    ctrl:SetScale(s)
    ctrl:SetOrigin(w * 0.5, h * 0.5)

    text:SetPosition(w * 0.5, h * 0.5)

    return ctrl
end

MakeClassOf(MenuButton, MenuEntry)

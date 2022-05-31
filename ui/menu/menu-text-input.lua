MenuTextInput = {}

function MenuTextInput:Init(screen, fieldName, masked, onEnter)
    MenuEntry.Init(self)
    self.screen = screen
    self.fieldName = fieldName
    self.masked = masked
    self.onEnter = onEnter
end

function MenuTextInput:CreateControl(parent)
    local ctrl = Control(parent)
    self.control = ctrl

    local input = TextInput(ctrl, self.screen, Consts.MENU_TEXT_INPUT_WIDTH, Consts.MENU_TEXT_INPUT_HEIGHT, self.masked, nil, self.onEnter)
    self.input = input
    input:SetPosition(Consts.MENU_TEXT_INPUT_FIELD_MARGIN, nil)
    local inputH = ctrl:GetRecursiveAabb(input):GetHeight()

    local text = Text(ctrl, self.fieldName, Consts.TEXT_COLOR)
    local textW, textH = text:GetSize()
    text:SetOrigin(textW, textH * 0.5)
    text:SetPosition(-Consts.MENU_TEXT_INPUT_FIELD_MARGIN, inputH * 0.5)
    text:SetScale(Consts.MENU_FIELD_SCALE)

    return ctrl
end

function MenuTextInput:GetText()
    return self.input:GetText()
end

MakeClassOf(MenuTextInput, MenuEntry)

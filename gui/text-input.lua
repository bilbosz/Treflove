TextInput = {}

local function UpdateView(self)
    self.background:SetColor(self.focus and Consts.BUTTON_SELECT_COLOR or self:IsHovered() and Consts.BUTTON_HOVER_COLOR or Consts.BUTTON_NORMAL_COLOR)
    self.caret:SetEnabled(self.focus)
    if self.focus then
        local textCtrl = self.textCtrl
        textCtrl:SetText(self:GetText())
        self.caret:SetPosition(self.padding + textCtrl:GetSize() * Consts.MENU_FIELD_SCALE)
        app.textEventManager:RegisterListener(self)
    else
        app.textEventManager:UnregisterListener(self)
    end
end

local function CreateBackground(self)
    self.background = Rectangle(self, self.width, self.height, Consts.BUTTON_NORMAL_COLOR)
end

local function CreateCaret(self)
    self.caret = Rectangle(self, 3, self.height - 2 * self.padding, Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self.caret:SetPosition(self.padding, self.padding)
end

local function CreateText(self)
    local text = Text(self, "", Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self.textCtrl = text

    text:SetOrigin(0, 11.5)
    text:SetScale(Consts.MENU_FIELD_SCALE)
    text:SetPosition(self.padding, self.height * 0.5)
end

function TextInput:Init(parent, width, height)
    Control.Init(self, parent)
    ButtonEventListener.Init(self)
    TextEventListener.Init(self)
    self.width = width
    self.height = height
    self.padding = 10
    self.focus = false
    CreateBackground(self)
    CreateCaret(self)
    CreateText(self)
    UpdateView(self)
    app.updateEventManager:RegisterListener(self)
    app.buttonEventManager:RegisterListener(self)
end

function TextInput:OnUpdate(dt)
    self.time = (self.time or 0) + dt
    self.caret:SetEnabled(self.focus and math.fmod(self.time, 1) >= 0.5)
end

function TextInput:OnPointerEnter()
    ButtonEventListener.OnPointerEnter(self)
    UpdateView(self)
end

function TextInput:OnPointerLeave()
    ButtonEventListener.OnPointerLeave(self)
    UpdateView(self)
end

function TextInput:OnClick()
    ButtonEventListener.OnClick(self)
    self.focus = true
    UpdateView(self)
end

function TextInput:OnAppendText(text)
    TextEventListener.OnAppendText(self, text)
    UpdateView(self)
end

function TextInput:OnRemoveCharacter()
    TextEventListener.OnRemoveCharacter(self)
    UpdateView(self)
end

MakeClassOf(TextInput, Control, UpdateEventListener, ButtonEventListener, TextEventListener)

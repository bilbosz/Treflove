TextInput = {}

local function UpdateBackgroundView(self)
    self.background:SetColor(self:IsFocused() and Consts.BUTTON_SELECT_COLOR or self:IsHovered() and Consts.BUTTON_HOVER_COLOR or Consts.BUTTON_NORMAL_COLOR)
end

local function UpdateTextView(self)
    local text = self.textCtrl
    if self.masked then
        text:SetText(string.rep("•", self:GetTextLength()))
    else
        text:SetText(self:GetText())
    end
end

local function UpdateCaretView(self)
    local caret = self.caret
    local isFocused = self:IsFocused()
    caret:SetEnable(isFocused)
    if isFocused then
        self.caretTime = 0
    end

    local text = self.textCtrl
    local w = text:GetSize() * text:GetScale()
    caret:SetPosition(w)
end

local function UpdateContentView(self)
    UpdateTextView(self)
    UpdateCaretView(self)

    local content = self.content
    local _, _, maxX, _ = content:GetGlobalAabb()
    local w = content:TransformToLocal(maxX, 0)
    if w > self.clip:GetSize() then
        content:SetOrigin(w, nil)
        content:SetPosition(self.clip:GetSize(), nil)
    else
        content:SetOrigin(0, nil)
        content:SetPosition(0, nil)
    end
end

local function UpdateView(self)
    UpdateBackgroundView(self)
    UpdateContentView(self)
    UpdateCaretView(self)

    if self:IsFocused() then
        app.textEventManager:RegisterListener(self)
    else
        app.textEventManager:UnregisterListener(self)
    end
end

local function CreateBackground(self)
    self.background = Rectangle(self, self.width, self.height, Consts.BUTTON_NORMAL_COLOR)
end

local function CreateClip(self)
    local clip = ClippingRectangle(self, self.width - 2 * self.padding, self.height)
    self.clip = clip

    clip:SetPosition(self.padding, 0)
end

local function CreateCaret(self)
    local h = self.height - 2 * self.padding
    local caret = Rectangle(self.content, Consts.CARET_WIDTH, h, Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self.caret = caret

    caret:SetOrigin(0, h * 0.5)
end

local function CreateText(self)
    local text = Text(self.content, "", Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self.textCtrl = text

    text:SetOrigin(0, 11.5)
    text:SetScale(Consts.MENU_FIELD_SCALE)
end

local function CreateContent(self)
    local content = Control(self.clip)
    self.content = content

    content:SetPosition(0, self.height * 0.5)

    CreateCaret(self)
    CreateText(self)
end

function TextInput:Init(parent, width, height, masked)
    Control.Init(self, parent)
    ButtonEventListener.Init(self)
    TextEventListener.Init(self)
    FocusEventListener.Init(self)
    self.width = width
    self.height = height
    self.padding = 10
    self.masked = masked or false
    self.caretTime = nil
    CreateBackground(self)
    CreateClip(self)
    CreateContent(self)
    UpdateView(self)
    app.updateEventManager:RegisterListener(self)
    app.buttonEventManager:RegisterListener(self)
    app.focusEventManager:RegisterListener(self)
end

function TextInput:OnUpdate(dt)
    local caret = self.caret
    if self:IsFocused() then
        local time = self.caretTime + dt
        self.caretTime = time
        caret:SetEnable(math.fmod(time, Consts.CARET_BLINK_INTERVAL * 2) <= Consts.CARET_BLINK_INTERVAL)
    else
        caret:SetEnable(false)
    end
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
    app.focusEventManager:Focus(self)
    UpdateView(self)
end

function TextInput:OnAppendText(...)
    TextEventListener.OnAppendText(self, ...)
    UpdateView(self)
end

function TextInput:OnRemoveText(...)
    TextEventListener.OnRemoveText(self, ...)
    UpdateView(self)
end

function TextInput:OnFocus()
    FocusEventListener.OnFocus(self)
    app.textEventManager:SetTextInput(true)
    UpdateView(self)
end

function TextInput:OnFocusLost()
    FocusEventListener.OnFocusLost(self)
    app.textEventManager:SetTextInput(false)
    UpdateView(self)
end

MakeClassOf(TextInput, Control, UpdateEventListener, ButtonEventListener, TextEventListener, FocusEventListener)

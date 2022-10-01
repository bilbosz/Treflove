TextInput = {}

local function UpdateBackgroundView(self)
    local color
    if self:IsFocused() then
        if self:IsMultivalueDefault() then
            color = Consts.BUTTON_MULTIVALUE_SELECT_COLOR
        else
            color = Consts.BUTTON_SELECT_COLOR
        end
    elseif self:IsHovered() then
        if self:IsMultivalueDefault() then
            color = Consts.BUTTON_MULTIVALUE_HOVER_COLOR
        else
            color = Consts.BUTTON_HOVER_COLOR
        end
    else
        if self:IsMultivalueDefault() then
            color = Consts.BUTTON_MULTIVALUE_NORMAL_COLOR
        else
            color = Consts.BUTTON_NORMAL_COLOR
        end
    end
    assert(color ~= nil)
    self.background:SetColor(color)
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
    local w = content:GetRecursiveAabb():GetWidth()
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
    local font = Consts.USER_INPUT_FONT
    local text = Text(self.content, "", Consts.TEXT_INPUT_FOREGROUND_COLOR, font)
    self.textCtrl = text

    text:SetOrigin(0, font:getHeight() * 0.5)
    text:SetScale(Consts.MENU_FIELD_SCALE)
end

local function CreateContent(self)
    local content = Control(self.clip)
    self.content = content

    content:SetPosition(0, self.height * 0.5)

    CreateCaret(self)
    CreateText(self)
end

function TextInput:Init(parent, screen, width, height, masked, onInput, onEnter)
    assert_type(screen, FormScreen)
    Control.Init(self, parent, width, height)
    ButtonEventListener.Init(self)
    TextEventListener.Init(self)
    Input.Init(self)
    self.screen = screen
    self.width = width
    self.height = height
    self.padding = 10
    self.masked = masked or false
    self.onInput = onInput
    self.onEnter = onEnter
    self.caretTime = nil
    self.isMultivalue = false
    self.hasNewValue = false
    CreateBackground(self)
    CreateClip(self)
    CreateContent(self)
    UpdateView(self)
    screen:AddInput(self)
    if screen:IsShowed() then
        self:OnScreenShow()
    end
end

function TextInput:OnScreenShow()
    app.updateEventManager:RegisterListener(self)
    app.buttonEventManager:RegisterListener(self)
end

function TextInput:OnScreenHide()
    app.updateEventManager:UnregisterListener(self)
    app.buttonEventManager:UnregisterListener(self)
    app.textEventManager:UnregisterListener(self)
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
    self.screen:Focus(self)
    UpdateView(self)
end

function TextInput:OnEdit(...)
    if self.isMultivalue then
        self.hasNewValue = true
    end
    UpdateView(self)
    if self.onInput then
        self.onInput()
    end
end

function TextInput:OnEnter()
    if self.onEnter then
        self.onEnter()
    end
    UpdateView(self)
end

function TextInput:OnRemoveEmpty()
    if self.isMultivalue then
        self.hasNewValue = not self.hasNewValue
    end
    UpdateView(self)
end

function TextInput:RemoveWord()
    if self.masked then
        self:SetText("")
    else
        TextEventListener.RemoveWord(self)
    end
end

function TextInput:OnFocus()
    Input.OnFocus(self)
    app.textEventManager:SetTextInput(true)
    UpdateView(self)
end

function TextInput:OnFocusLost()
    Input.OnFocusLost(self)
    app.textEventManager:SetTextInput(false)
    UpdateView(self)
end

function TextInput:SetText(text)
    TextEventListener.SetText(self, text)
    UpdateView(self)
end

function TextInput:SetMultivalue(value)
    if value then
        TextEventListener.SetText(self, "")
    end
    self.isMultivalue = value
    self.hasNewValue = false
    UpdateView(self)
end

function TextInput:IsMultivalue()
    return self.isMultivalue
end

function TextInput:IsMultivalueDefault()
    return self.isMultivalue and not self.hasNewValue
end

MakeClassOf(TextInput, Control, UpdateEventListener, ButtonEventListener, TextEventListener, Input)

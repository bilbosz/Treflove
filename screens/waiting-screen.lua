WaitingScreen = {}

local function CreateBackground(self)
    Rectangle(self.screen, app.width, app.height, Consts.BACKGROUND_COLOR)
end

local function CreateLayout(self)
    local layout = Control(self.screen)
    self.layout = layout

    layout:SetPosition(app.width * 0.5, app.height * 0.5)
end

local function CreateLogo(self)
    local logo = Logo(self.layout)
    self.logo = logo
    logo:SetPosition(0, -15)
end

local function CreateText(self)
    local text = Text(self.layout, self.message, Consts.TEXT_COLOR)
    self.text = text
    text:SetPosition(0, 100)
    local textW = text:GetSize()
    text:SetOrigin(textW * 0.5, 0)
    text:SetScale(Consts.MENU_TITLE_SCALE)
end

local function CenterLayout(self)
    local layout = self.layout
    local _, minY, _, maxY = layout:GetGlobalAabb()
    local h = maxY - minY
    local s = app.root:GetScale()
    layout:SetOrigin(0, h * 0.5 / s)
end

function WaitingScreen:Init(message)
    Screen.Init(self)
    self.message = message
    app.updateEventManager:RegisterListener(self)
end

function WaitingScreen:OnPush()
    Screen.OnPush(self)

    CreateBackground(self)
    CreateLayout(self)
    CreateLogo(self)
    CreateText(self)
    CenterLayout(self)
end

function WaitingScreen:OnPop()
    Screen.OnPop(self)
end

function WaitingScreen:OnBackground()
    Screen.OnBackground(self)
end

function WaitingScreen:OnForeground()
    Screen.OnForeground(self)
end

function WaitingScreen:OnUpdate(dt)
    local logo = self.logo
    logo:SetRotation(logo:GetRotation() + dt)
end

MakeClassOf(WaitingScreen, Screen, UpdateEventListener)

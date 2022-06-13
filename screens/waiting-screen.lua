WaitingScreen = {}

local function CreateBackground(self)
    self.background = Rectangle(self.screen, app.width, app.height, Consts.BACKGROUND_COLOR)
end

local function CreateLayout(self)
    self.layout = Control(self.screen)
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
    local aabb = layout:GetGlobalRecursiveAabb()
    local h = aabb:GetHeight()
    local s = app.root:GetScale()
    layout:SetPosition(app.width * 0.5, app.height * 0.5)
    layout:SetOrigin(0, h * 0.5 / s)
end

function WaitingScreen:Init(message)
    Screen.Init(self)
    self.message = message

    CreateBackground(self)
    CreateLayout(self)
    CreateLogo(self)
    CreateText(self)
    app.updateEventManager:RegisterListener(self)
end

function WaitingScreen:Show()
    Screen.Show(self)
    self:OnResize(app.width, app.height)
end

function WaitingScreen:OnResize(w, h)
    self.background:SetSize(w, h)
    CenterLayout(self)
end

function WaitingScreen:OnUpdate(dt)
    local logo = self.logo
    logo:SetRotation(logo:GetRotation() + dt)
end

MakeClassOf(WaitingScreen, Screen, UpdateEventListener)

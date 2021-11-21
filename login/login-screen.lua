LoginScreen = {}

local INPUT_WIDTH = 200
local INPUT_HEIGHT = 50
local FIELD_MARGIN = 25

local function CreateBackground(self)
    self.background = Rectangle(self.screen, app.width, app.height, Consts.BACKGROUND_COLOR)
end

local function CreateLayout(self)
    local layout = Control(self.screen)
    self.layout = layout
    layout:SetPosition(app.width * 0.5, app.height * 0.5)
end

local function CreateLogo(self)
    local logo = Logo(self.layout)
    logo:SetPosition(0, 0)
end

local function CreateTitle(self)
    local text = Text(self.layout, "Welcome", Consts.TEXT_COLOR)
    self.title = text

    local w, h = text:GetSize()
    text:SetOrigin(w * 0.5, h * 0.5)
    text:SetPosition(0, 150)
    text:SetScale(Consts.MENU_TITLE_SCALE)
end

local function CreateTextField(self, text, y)
    local text = Text(self.layout, text, Consts.TEXT_COLOR)
    local textW, textH = text:GetSize()
    text:SetOrigin(textW, textH * 0.5)
    text:SetPosition(-FIELD_MARGIN, y)
    text:SetScale(Consts.MENU_FIELD_SCALE)

    local input = TextInput(self.layout, INPUT_WIDTH, INPUT_HEIGHT)
    self.loginInput = input
    input:SetOrigin(0, INPUT_HEIGHT * 0.5)
    input:SetPosition(FIELD_MARGIN, y)
end

local function CreateLoginField(self)
    CreateTextField(self, "Login", 250)
end

local function CreatePasswordField(self)
    CreateTextField(self, "Password", 350)
end

local function CreateLoginButton(self)
    local button = TextButton(self.layout, "Log In", function()
        app.logger:Log("Log In button clicked")
    end)
    self.loginButton = button

    local w = button:GetSize()
    button:SetOrigin(w * 0.5, 0)
    button:SetPosition(0, 425)
    button:SetScale(Consts.MENU_BUTTON_SCALE)
end

local function CreateQuitButton(self)
    local button = TextButton(self.layout, "Quit", function()
        app:Quit()
    end)
    self.exitButton = button

    local w = button:GetSize()
    button:SetOrigin(w * 0.5, 0)
    button:SetPosition(0, 500)
    button:SetScale(Consts.MENU_BUTTON_SCALE)
end

local function CenterLayout(self)
    local layout = self.layout
    local _, minY, _, maxY = layout:GetGlobalAabb()
    local h = maxY - minY
    local s = app.root:GetScale()
    layout:SetOrigin(0, h * 0.5 / s)
end

function LoginScreen:Init()
    Screen.Init(self)
end

function LoginScreen:OnPush()
    Screen.OnPush(self)
    CreateBackground(self)
    CreateLayout(self)
    CreateLogo(self)
    CreateTitle(self)
    CreateLoginField(self)
    CreatePasswordField(self)
    CreateLoginButton(self)
    CreateQuitButton(self)
    CenterLayout(self)
end

MakeClassOf(LoginScreen, Screen)

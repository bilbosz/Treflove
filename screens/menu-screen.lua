MenuScreen = {}

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
    local text = Text(self.layout, self.title, Consts.TEXT_COLOR)
    self.title = text

    local w, h = text:GetSize()
    text:SetOrigin(w * 0.5, h * 0.5)
    text:SetPosition(0, 150)
    text:SetScale(Consts.MENU_TITLE_SCALE)
end

local function CenterLayout(self)
    local layout = self.layout
    local aabb = layout:GetRecursiveAabb()
    layout:SetOrigin(0, aabb:GetHeight() * 0.5)
end

local function CreateEntries(self)
    local y = 250
    for _, entryDef in ipairs(self.entries) do
        local ctrl = entryDef:CreateControl(self.layout)
        ctrl:SetPosition(nil, y)
        y = self.layout:GetRecursiveAabb(ctrl):GetMaxY() + Consts.MENU_ENTRY_VSPACING
    end
end

function MenuScreen:Init(title, entries)
    self.title = title
    self.entries = entries
end

function MenuScreen:OnPush()
    Screen.OnPush(self)
    CreateBackground(self)
    CreateLayout(self)
    CreateLogo(self)
    CreateTitle(self)
    CreateEntries(self)
    CenterLayout(self)
end

MakeClassOf(MenuScreen, Screen)

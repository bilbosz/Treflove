WaitingScreen = {}

function WaitingScreen:Init(message)
    Screen.Init(self)
    self.message = message
    app.updateEventManager:RegisterListener(self)
end

function WaitingScreen:OnPush()
    Screen.OnPush(self)
    local logo = Logo(self.screen)
    self.logo = logo
    logo:SetPosition(app.width * 0.5, app.height * 0.5 - 15)
    local logoH = select(2, logo:GetSize())

    local text = Text(self.screen, self.message, {
        0.9,
        0.9,
        0.9
    })
    self.text = text
    text:SetPosition(app.width * 0.5, app.height * 0.5 + logoH * 0.5)
    local textW = text:GetSize()
    text:SetOrigin(textW * 0.5, 0)
    text:SetScale(3)
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

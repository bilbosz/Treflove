ScreenSaver = {}

function ScreenSaver:Init()
    Screen.Init(self)
end

function ScreenSaver:OnPush()
    Screen.OnPush(self)
    self.screen:SetSize(app.width, app.height)

    self.background = Rectangle(self.screen, app.width, app.height, {
        255,
        255,
        255,
        255
    })

    self.logo = Logo(self.screen)

    self.dirRot = 1
    self.dirX, self.dirY = 1, 1

    app.updateEventManager:RegisterListener(self)
end

function ScreenSaver:OnUpdate(dt)
    local logo = self.logo
    logo:SetRotation(logo:GetRotation() + dt * self.dirRot)

    local x, y = logo:GetPosition()
    local r = logo:GetSize() * 0.5
    local w, h = self.screen:GetSize()
    local move = 60 * dt

    local newX, newY = x + self.dirX * move, y + self.dirY * move

    local collided = false
    if newX - r < 0 then
        collided = true
        self.dirX = -self.dirX
        newX = -(newX - r) + r
    end
    if newX + r >= w then
        collided = true
        self.dirX = -self.dirX
        newX = w - ((newX + r) - w) - r
    end
    if newY - r < 0 then
        collided = true
        self.dirY = -self.dirY
        newY = -(newY - r) + r
    end
    if newY + r >= h then
        collided = true
        self.dirY = -self.dirY
        newY = h - ((newY + r) - h) - r
    end
    if collided then
        for k = 1, 3 do
            self.logo.color[k] = math.random()
        end
        self.dirRot = -self.dirRot
    end

    logo:SetPosition(newX, newY)
end

MakeClassOf(ScreenSaver, Screen, UpdateEventListener)

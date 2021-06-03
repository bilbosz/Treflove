Game = class("Game")

Loader:Load("controls/control.lua")
Loader:Load("controls/drawable-control.lua")
Loader:Load("controls/rectangle.lua")
Loader:Load("game/game-object.lua")
Loader:Load("controls/image.lua")

local function UpdateRootScale(self)
    local w, h = love.graphics:getDimensions()
    assert(w >= h)
    local modelW = 2000
    self.root:SetScale(w / modelW)
end

function Game:Init()
    self.root = Control()
    UpdateRootScale(self)
    self.rect1 = Rectangle(self.root, 1000, 500, {255, 0, 0, 255})
    self.image = Image(self.root, "game/world/world.jpg")
    self.image:SetPosition(1000, 500)
    self.image:SetOrigin(0, 555)
end

function Game:Draw()
    self.root:Draw()
end

function Game:Update(dt)
    self.root:Update(dt)
    self.total = self.total or 0
    self.total = self.total + dt
    self.image:SetRotation(self.total)
end

function Game:WheelMoved(_, _)
end

function Game:MousePressed(x, y, button)
    if button == 2 then
        self.rmbX, self.rmbY = x, y
    end
end

function Game:KeyPressed(code)

end

function Game:MouseReleased(_, _, button)
    if button == 2 then
        self.rmbX, self.rmbY = nil, nil
    end
end

function Game:MouseMoved(x, y)
    if self.rmbX then
        self.rmbX, self.rmbY = x, y
    end
end

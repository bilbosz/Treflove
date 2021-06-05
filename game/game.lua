Game = class("Game")

Loader:Load("controls/control.lua")
Loader:Load("controls/drawable-control.lua")
Loader:Load("controls/rectangle.lua")
Loader:Load("game/game-object.lua")
Loader:Load("controls/image.lua")
Loader:Load("controls/clipping.lua")
Loader:Load("game/world/world.lua")

local function UpdateRootScale(self)
    self.root:SetScale(self.realW / self.modelW)
end

function Game:Init()
    self.realW, self.realH = love.graphics:getDimensions()
    assert(self.realW >= self.realH)
    self.modelW = 2000
    self.modelH = self.realH / self.realW * self.modelW

    self.root = Control()
    UpdateRootScale(self)

    self.world = World(self.root, 1200, 800, "game/world/world.jpg", 175.61)
    self.world:SetPosition(300, 0)
end

function Game:Draw()
    self.root:Draw()
    love.graphics.reset()
end

function Game:Update(dt)
    self.root:Update(dt)
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

Loader:Load("controls/control.lua")
Loader:Load("controls/drawable-control.lua")
Loader:Load("controls/rectangle.lua")
Loader:Load("game/game-object.lua")
Loader:Load("controls/image.lua")
Loader:Load("controls/clipping-rectangle.lua")
Loader:Load("controls/clipping-mask.lua")
Loader:Load("controls/text.lua")
Loader:Load("game/world/world.lua")

Game = {}

local function UpdateRootScale(self)
    self.root:SetScale(self.realW / self.modelW)
end

function Game:Init(data)
    self.realW, self.realH = love.graphics:getDimensions()
    assert(self.realW >= self.realH)
    self.modelW = 2000
    self.modelH = self.realH / self.realW * self.modelW

    self.root = Control()
    UpdateRootScale(self)

    self.data = data
    if data.screen == "World" then
        self.screen = World(self.root, self.modelW, self.modelH, data.params)
    end
end

function Game:Draw()
    self.root:Draw()
    love.graphics.reset()
end

function Game:Update(dt)
    self.root:Update(dt)
end

function Game:KeyPressed(code)

end

function Game:MousePressed(x, y, button)
    self.root:MousePressed(x, y, button)
end

function Game:MouseReleased(x, y, button)
    self.root:MouseReleased(x, y, button)
end

function Game:MouseMoved(x, y)
    self.root:MouseMoved(x, y)
end

function Game:WheelMoved(x, y)
    self.root:WheelMoved(x, y)
end

MakeClassOf(Game)
Game = {}

function Game:Init()
    Screen.Init(self)
end

function Game:OnPush()
    Screen.OnPush(self)
    if self.data.screen == "World" then
        World(self.data.params, self.screen, app.width, app.height)
    end
end

MakeModelOf(Game, Screen)

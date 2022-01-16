GameScreen = {}

function GameScreen:Init()
    Screen.Init(self)
end

function GameScreen:OnPush()
    Screen.OnPush(self)
    if self.data.screen == "World" then
        World(self.data.params, self.screen, app.width, app.height)
    end
end

MakeModelOf(GameScreen, Screen)

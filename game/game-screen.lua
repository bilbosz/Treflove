GameScreen = {}

function GameScreen:Init(data)
    Model.Init(self, data)
    Screen.Init(self)
end

function GameScreen:Show()
    Screen.Show(self)
    if self.data.screen == "World" then
        World(self.data.params, self.screen, app.width, app.height)
        app.backstackManager:Push(function()
            app.screenManager:Show(UserMenuScreen(app.session))
        end)
    end
end

MakeClassOf(GameScreen, Model, Screen)

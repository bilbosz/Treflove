GameScreen = {}

function GameScreen:Init(data)
    Model.Init(self, data)
    Screen.Init(self)
    if self.data.screen == "World" then
        self.world = World(self.data.params, self.screen, app.width, app.height)
    end
end

function GameScreen:Show()
    Screen.Show(self)
    self.world:SetSize(app.width, app.height)
    app.backstackManager:Push(function()
        app.screenManager:Show(UserMenuScreen(app.session))
    end)
end

function GameScreen:OnResize(w, h)
    self.world:SetSize(w, h)
end

MakeClassOf(GameScreen, Model, Screen)

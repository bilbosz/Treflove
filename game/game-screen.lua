GameScreen = {}

function GameScreen:Init(data)
    Model.Init(self, data)
    Screen.Init(self)
    if self.data.page == "World" then
        self.page = Page(self.data.params, self.screen, app.width * 0.8, app.height)
        self.panel = Panel(self.screen, app.width * 0.2, app.height)
    end
end

function GameScreen:Show()
    Screen.Show(self)
    self:OnResize(app.width, app.height)
    app.backstackManager:Push(function()
        app.screenManager:Show(UserMenuScreen(app.session))
    end)
end

function GameScreen:OnResize(w, h)
    self.page:SetSize(w * 0.8, h)
    self.panel:SetSize(w * 0.2, h)
    self.panel:SetPosition(w * 0.8, 0)
end

MakeClassOf(GameScreen, Model, Screen)

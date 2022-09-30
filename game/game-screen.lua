GameScreen = {}

function GameScreen:Init(data)
    Model.Init(self, data)
    FormScreen.Init(self)
    self.page = Page(app.data.pages[data.page], self, app.width * 0.8, app.height, self.panel)
    self.panel = TokenPanel(self, app.width * 0.2, app.height)
end

function GameScreen:Show()
    self:OnResize(app.width, app.height)
    FormScreen.Show(self)
    app.backstackManager:Push(function()
        app.screenManager:Show(UserMenuScreen(app.session))
    end)
end

function GameScreen:OnSelectionChange()
    self.panel:OnSelectionChange()
end

function GameScreen:OnResize(w, h)
    self.page:SetSize(w * 0.8, h)
    self.panel:SetSize(w * 0.2, h)
    self.panel:SetPosition(w * 0.8, 0)
    self.panel:UpdateView()
end

function GameScreen:GetPage()
    return self.page
end

function GameScreen:GetSelection()
    return self.page:GetSelection()
end

function GameScreen:GetTokenPanel()
    return self.panel
end

MakeClassOf(GameScreen, Model, FormScreen)

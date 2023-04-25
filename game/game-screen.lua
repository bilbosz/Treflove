GameScreen = {}

function GameScreen:Init(data)
    Model.Init(self, data)
    FormScreen.Init(self)
    self.page = Page(app.data.pages[data.page], self, app.width * 0.8, app.height, self.tokenPanel)
    self.tokenPanel = TokenPanel(self, app.width * 0.2, app.height)
    self.assetsPanel = AssetsPanel(self, app.width * 0.2, app.height)

    self.tokenPanel:SetEnable(false)
    self.assetsPanel:SetEnable(true)
end

function GameScreen:Release()
    self.assetsPanel:Release()
end

function GameScreen:Show()
    self:OnResize(app.width, app.height)
    FormScreen.Show(self)
    app.backstackManager:Push(function()
        self:Release()
        app.screenManager:Show(UserMenuScreen(app.session))
    end)
end

function GameScreen:OnSelectionChange()
    self.tokenPanel:OnSelectionChange()
end

function GameScreen:OnResize(w, h)
    self.page:SetSize(w * 0.8, h)

    self.tokenPanel:SetPosition(w * 0.8, 0)
    self.tokenPanel:OnResize(w * 0.2, h)

    self.assetsPanel:SetPosition(w * 0.8, 0)
    self.assetsPanel:OnResize(w * 0.2, h)
end

function GameScreen:GetPage()
    return self.page
end

function GameScreen:GetSelection()
    return self.page:GetSelection()
end

function GameScreen:GetTokenPanel()
    return self.tokenPanel
end

MakeClassOf(GameScreen, Model, FormScreen)

GameScreen = {}

function GameScreen:Init(data)
    Model.Init(self, data)
    FormScreen.Init(self)

    self.page = Page(app.data.pages[data.page], self, app.width * 0.8, app.height)

    self.tokenPanel = TokenPanel(self, app.width * 0.2, app.height)
    self.assetsPanel = AssetsPanel(self, app.width * 0.2, app.height)

    self.panel = nil
    local panels = {
        self.tokenPanel,
        self.assetsPanel
    }
    self.panels = panels
    for _, v in ipairs(panels) do
        v:SetEnabled(false)
    end

    self.quickAccessPanel = QuickAccessPanel(self, app.width * 0.8, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self.quickAccessPanel:AddEntry("Tokens", self.tokenPanel)
    self.quickAccessPanel:AddEntry("Assets", self.assetsPanel)
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
    self.page:SetPosition(0, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self.page:SetSize(w * 0.8, h - Consts.QUICK_ACCESS_PANEL_HEIGHT)

    self.quickAccessPanel:SetPosition(0, 0)
    self.quickAccessPanel:OnResize(w * 0.8, Consts.QUICK_ACCESS_PANEL_HEIGHT)

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

function GameScreen:SelectPanel(panel)
    assert(table.findidx(self.panels, panel))
    self:DisablePanel()
    self.panel = panel
    panel:SetEnabled(true)
end

function GameScreen:DisablePanel()
    if self.panel then
        self.panel:SetEnabled(false)
        self.panel = nil
    end
end

MakeClassOf(GameScreen, Model, FormScreen)

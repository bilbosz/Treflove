QuickAccessPanel = {}

function QuickAccessPanel:Init(gameScreen, width, height)
    Panel.Init(self, gameScreen:GetControl(), width, height)
    self.gameScreen = gameScreen
    self.entries = {}
end

function QuickAccessPanel:AddEntry(label, entry)
    local children = self:GetChildren()
    local x = 0
    if #children > 1 then
        local lastChild = children[#children]
        x = lastChild:GetPosition() + lastChild:GetOuterSize()
    end
    x = x + Consts.PADDING
    local button = TextButton(self, self.gameScreen, label, function()
        self.gameScreen:SelectPanel(entry)
    end)
    self.entries[entry] = button

    button:SetPosition(x, Consts.PADDING)
    button:SetScale(Consts.PANEL_FIELD_SCALE)
end

MakeClassOf(QuickAccessPanel, Panel)

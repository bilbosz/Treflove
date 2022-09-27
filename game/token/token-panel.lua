TokenPanel = {}

function TokenPanel:Init(gameScreen, width, height)
    Panel.Init(self, gameScreen:GetControl(), width, height)
    self.gameScreen = gameScreen
    self.properties = {}
    self.selectionSet = nil
end

function TokenPanel:UpdateSelection(selection)
    self.selectionSet = selection:GetSelectSet()
    self:UpdateView()
end

function TokenPanel:UpdateView()
    self:ReleaseProperties()
    self:UpdatePropertyKeys()
    self:FillInProperties()
end

function TokenPanel:UpdatePropertyKeys()
    local uniqueKeys = {}
    for token in pairs(self.selectionSet) do
        for k in pairs(token:GetData()) do
            uniqueKeys[k] = true
        end
    end
    local keys = {}
    for k in pairs(uniqueKeys) do
        if app.data.token_properties[k].type == "string" then
            table.insert(keys, k)
        end
    end
    table.sort(keys)
    self.keys = keys
end

function TokenPanel:FillInProperties()
    local y = 0
    local panelW = self:GetSize()
    for _, k in pairs(self.keys) do
        if app.data.token_properties[k] then
            local propertyDef = app.data.token_properties[k]
            local property = {
                key = k,
                title = nil,
                input = nil
            }
            do
                local title = Text(self, propertyDef.title)

                property.title = title
                title:SetScale(Consts.TOKEN_PANEL_PROPERTY_SCALE)
                title:SetPosition(Consts.TOKEN_PANEL_PROPERTY_MARGIN, y)
                local h = select(2, title:GetSize())
                y = y + h * Consts.TOKEN_PANEL_PROPERTY_SCALE
            end

            do
                local input = TextInput(self, self.gameScreen, panelW - 2 * Consts.TOKEN_PANEL_PROPERTY_MARGIN, 50)
                property.input = input
                input:SetPosition(Consts.TOKEN_PANEL_PROPERTY_MARGIN, y)
                local h = select(2, input:GetSize())
                y = y + h

                local once = true
                local lastValue
                for token in pairs(self.selectionSet) do
                    local value = token:GetData()[k]
                    if once then
                        once = false
                        lastValue = value
                    elseif lastValue ~= value then
                        lastValue = nil
                    end
                end
                if lastValue then
                    input:SetText(lastValue)
                end
            end
            table.insert(self.properties, property)

            y = y + Consts.TOKEN_PANEL_PROPERTY_MARGIN
        end
    end
end

function TokenPanel:ReleaseProperties()
    self.gameScreen:RemoveAllInputs()
    for _, v in pairs(self.properties) do
        v.title:SetParent(nil)
        v.input:SetParent(nil)
    end
    self.properties = {}
end

MakeClassOf(TokenPanel, Panel)

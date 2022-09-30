TokenPanel = {}

function TokenPanel:Init(gameScreen, width, height)
    Panel.Init(self, gameScreen:GetControl(), width, height)
    self.gameScreen = gameScreen
    self.properties = {}
    self.selectionSet = gameScreen:GetSelection():GetSelectSet()
    self.cancelButton = nil
    self.applyButton = nil
end

function TokenPanel:OnSelectionChange()
    self.selectionSet = self.gameScreen:GetSelection():GetSelectSet()
    self:UpdateView()
end

function TokenPanel:UpdateView()
    self:ReleaseProperties()
    self:UpdatePropertyKeys()
    self:FillInProperties()
    self:CreateCancelButton()
    self:CreateApplyButton()
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
    for _, k in pairs(self.keys) do
        if app.data.token_properties[k] then
            local propertyDef = app.data.token_properties[k]
            local property = {
                key = k,
                title = nil,
                input = nil
            }

            do
                local title = self:CreatePropertyTitle(propertyDef)
                property.title = title
                title:SetPosition(Consts.PADDING, y)
                local h = select(2, title:GetSize())
                y = y + h * title:GetScale()
            end

            do
                local input = self:CreatePropertyInput(propertyDef)
                property.input = input
                input:SetPosition(Consts.PADDING, y)
                local h = select(2, input:GetSize())
                y = y + h

                local isSingleValue, value = self:GetValueByKey(k)
                if isSingleValue then
                    input:SetText(value)
                else
                    input:SetMultivalue(true)
                end
            end

            table.insert(self.properties, property)

            y = y + Consts.PADDING
        end
    end
end

function TokenPanel:CreatePropertyTitle(propertyDef)
    local title = Text(self, propertyDef.title, Consts.TEXT_COLOR)
    title:SetScale(Consts.MENU_FIELD_SCALE)
    return title
end

function TokenPanel:CreatePropertyInput(propertyDef)
    local panelW = self:GetSize()
    local input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.MENU_TEXT_INPUT_HEIGHT, false, nil, function()
        self:Apply()
    end)
    return input
end

function TokenPanel:GetValueByKey(key)
    local once = true
    local value
    for token in pairs(self.selectionSet) do
        local current = token:GetData()[key]
        if once then
            once = false
            value = current
        elseif value ~= current then
            return false, nil
        end
    end
    return true, value
end

function TokenPanel:CreateCancelButton()
    local h = select(2, self:GetSize())

    local button = TextButton(self, self.gameScreen, "Cancel", function()
        self:Cancel()
    end)
    self.cancelButton = button

    local s = 0.3
    button:SetScale(s)

    local buttonH = select(2, button:GetSize())
    button:SetPosition(Consts.PADDING, h - buttonH * s - Consts.PADDING)
end

function TokenPanel:CreateApplyButton()
    local w, h = self:GetSize()

    local button = TextButton(self, self.gameScreen, "Apply", function()
        self:Apply()
    end)
    self.applyButton = button

    local s = 0.3
    button:SetScale(s)

    local buttonW, buttonH = button:GetSize()
    button:SetPosition(w - buttonW * s - Consts.PADDING, h - buttonH * s - Consts.PADDING)
end

function TokenPanel:ReleaseProperties()
    self.gameScreen:RemoveAllInputs()
    for _, v in ipairs(self.properties) do
        v.title:SetParent(nil)
        v.input:SetParent(nil)
    end
    self.properties = {}

    if self.cancelButton then
        self.cancelButton:SetParent(nil)
        self.cancelButton = nil
    end

    if self.applyButton then
        self.applyButton:SetParent(nil)
        self.applyButton = nil
    end
end

function TokenPanel:Apply()
    app:Log("Apply")
end

function TokenPanel:Cancel()
    self.gameScreen:GetSelection():Unselect()
end

MakeClassOf(TokenPanel, Panel)

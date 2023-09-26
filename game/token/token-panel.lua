TokenPanel = {}

function TokenPanel:Init(gameScreen, width, height)
    Panel.Init(self, gameScreen:GetControl(), width, height)
    self.gameScreen = gameScreen
    self.properties = {}
    self.keys = nil
    self.selectionSet = gameScreen:GetSelection():GetSelectSet()
    self.cancelButton = nil
    self.applyButton = nil
end

function TokenPanel:OnResize(w, h)
    Panel.OnResize(self, w, h)
    self:UpdateView()
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
        local t = app.data.token_properties[k].type
        if t == "string" or t == "number" then
            table.insert(keys, k)
        end
    end
    table.sort(keys)
    self.keys = keys
end

function TokenPanel:FillInProperties()
    local y = 0
    for _, k in ipairs(self.keys) do
        if app.data.token_properties[k] then
            local property = {
                key = k,
                def = app.data.token_properties[k],
                title = nil,
                input = nil
            }

            do
                local title = self:CreatePropertyTitle(property)
                property.title = title
                title:SetPosition(Consts.PADDING, y)
                local h = select(2, title:GetSize())
                y = y + h * title:GetScale()
            end

            do
                local input = self:CreatePropertyInput(property)
                property.input = input
                input:SetPosition(Consts.PADDING, y)
                local h = select(2, input:GetSize())
                y = y + h

                local isSingleValue, value = self:GetValueByKey(k)
                if isSingleValue then
                    local t = property.def.type
                    if t == "string" then
                        input:SetText(value)
                    elseif t == "number" then
                        input:SetNumber(value)
                    end
                else
                    input:SetMultivalue(true)
                end
            end

            table.insert(self.properties, property)

            y = y + Consts.PADDING
        end
    end
end

function TokenPanel:CreatePropertyTitle(property)
    local title = Text(self, property.def.title, Consts.FOREGROUND_COLOR)
    title:SetScale(Consts.PANEL_FIELD_SCALE)
    return title
end

function TokenPanel:CreatePropertyInput(property)
    local panelW = self:GetSize()

    local t = property.def.type
    local apply = function()
        self:Apply()
    end
    local input
    if t == "string" then
        input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, false, nil, apply)
    elseif t == "number" then
        input = NumberInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, nil, apply)
    else
        assert(false)
    end
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

    local s = Consts.PANEL_FIELD_SCALE
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

    local s = Consts.PANEL_FIELD_SCALE
    button:SetScale(s)

    local buttonW, buttonH = button:GetSize()
    button:SetPosition(w - buttonW * s - Consts.PADDING, h - buttonH * s - Consts.PADDING)
end

function TokenPanel:ReleaseProperties()
    for _, v in ipairs(self.properties) do
        v.title:SetParent(nil)

        self.gameScreen:RemoveInput(v.input)
        v.input:SetParent(nil)
    end
    self.properties = {}

    if self.cancelButton then
        self.gameScreen:RemoveInput(self.cancelButton)
        self.cancelButton:SetParent(nil)
        self.cancelButton = nil
    end

    if self.applyButton then
        self.gameScreen:RemoveInput(self.applyButton)
        self.applyButton:SetParent(nil)
        self.applyButton = nil
    end
end

function TokenPanel:Apply()
    for _, property in ipairs(self.properties) do
        if not property.input:IsMultivalueDefault() then
            local t = property.def.type
            if t == "string" then
                local key, value = property.key, property.input:GetText()
                for token in pairs(self.selectionSet) do
                    local old = token:GetData()[key]
                    if old ~= value then
                        token:SetData(key, value)
                    end
                end
            elseif t == "number" then
                local key, value = property.key, property.input:GetNumber()
                for token in pairs(self.selectionSet) do
                    local old = token:GetData()[key]
                    if old ~= value then
                        token:SetData(key, value)
                    end
                end
            else
                assert(false)
            end
        end
    end
end

function TokenPanel:Cancel()
    self.gameScreen:GetSelection():Unselect()
end

MakeClassOf(TokenPanel, Panel)

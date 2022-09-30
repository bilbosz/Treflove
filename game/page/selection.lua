Selection = {}

local function UpdateRectangle(self)
    local aabb = Aabb()
    aabb:AddPoint(unpack(self.startPoint))
    aabb:AddPoint(unpack(self.endPoint))
    self:SetPosition(aabb:GetPosition())
    self:SetSize(aabb:GetSize())
end

function Selection:Init(page)
    assert_type(page, Page)
    self.page = page
    Rectangle.Init(self, self.page:GetPageCoordinates(), 0, 0, Consts.PAGE_SELECTION_COLOR)
    self:SetEnable(false)
    self.startPoint = {
        0,
        0
    }
    self.endPoint = {
        0,
        0
    }
    self.selectSet = {}
    app.updateEventManager:RegisterListener(self)
end

function Selection:Show()
    self:SetEnable(true)
end

function Selection:Hide()
    self:SetEnable(false)
end

function Selection:SetStartPoint(x, y)
    assert(not self:IsEnable())
    self:Show()
    self.startPoint[1], self.startPoint[2] = x, y
    self.endPoint[1], self.endPoint[2] = x, y
    UpdateRectangle(self)
end

function Selection:SetEndPoint(x, y)
    assert(self:IsEnable())
    self.endPoint[1], self.endPoint[2] = x, y
    UpdateRectangle(self)
end

function Selection:Apply()
    self.selectSet = {}
    local aabb = self:GetAabb()
    for _, token in ipairs(self.page:GetTokens()) do
        local x, y = token:GetPosition()
        local r = token:GetRadius()
        local intersects = aabb:DoesCircleIntersect(x, y, r)
        self.selectSet[token] = intersects or nil
        token:SetSelect(intersects)
    end
    self:OnSelectionChange()
end

function Selection:AddApply()
    local aabb = self:GetAabb()
    for _, token in ipairs(self.page:GetTokens()) do
        local x, y = token:GetPosition()
        local r = token:GetRadius()
        local intersects = aabb:DoesCircleIntersect(x, y, r)
        if intersects then
            self.selectSet[token] = true
            token:SetSelect(true)
        end
    end
    self:OnSelectionChange()
end

function Selection:ToggleApply()
    local aabb = self:GetAabb()
    for _, token in ipairs(self.page:GetTokens()) do
        local x, y = token:GetPosition()
        local r = token:GetRadius()
        local intersects = aabb:DoesCircleIntersect(x, y, r)
        if intersects then
            local newSelect = not token:GetSelect()
            self.selectSet[token] = newSelect or nil
            token:SetSelect(newSelect)
        end
    end
    self:OnSelectionChange()
end

function Selection:Unselect()
    for _, token in ipairs(self.page:GetTokens()) do
        self.selectSet[token] = nil
        token:SetSelect(false)
    end
    self:OnSelectionChange()
end

function Selection:GetSelectSet()
    return self.selectSet
end

function Selection:OnSelectionChange()
    self.page:GetGameScreen():OnSelectionChange()
end

function Selection:OnUpdate()
    self:Reattach()
end

MakeClassOf(Selection, Rectangle, UpdateEventListener)

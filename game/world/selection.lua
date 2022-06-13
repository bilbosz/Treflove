Selection = {}

local function UpdateRectangle(self)
    local aabb = Aabb()
    aabb:AddPoint(unpack(self.startPoint))
    aabb:AddPoint(unpack(self.endPoint))
    self:SetPosition(aabb:GetPosition())
    self:SetSize(aabb:GetSize())
end

function Selection:Init(world)
    self.world = world
    Rectangle.Init(self, self.world:GetWorldCoordinates(), 0, 0, Consts.WORLD_SELECTION_COLOR)
    self:SetEnable(false)
    self.startPoint = {
        0,
        0
    }
    self.endPoint = {
        0,
        0
    }
    app.updateEventManager:RegisterListener(self)
end

function Selection:Reset()
    self:SetEnable(false)
end

function Selection:SetStartPoint(x, y)
    assert(not self:IsEnable())
    self:SetEnable(true)
    self.startPoint[1], self.startPoint[2] = x, y
    self.endPoint[1], self.endPoint[2] = x, y
    UpdateRectangle(self)
end

function Selection:SetEndPoint(x, y)
    assert(self:IsEnable())
    self.endPoint[1], self.endPoint[2] = x, y
    UpdateRectangle(self)
end

function Selection:OnUpdate()
    self:Reattach()
end

MakeClassOf(Selection, Rectangle, UpdateEventListener)

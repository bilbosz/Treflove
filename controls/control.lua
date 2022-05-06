Control = {}

--[[
    Transformations
        Link: https://learnopengl.com/Getting-started/Transformations
        Order:
            Origin
            Scaling
            Rotation
            Position
]]

local function UpdateLocalTransform(self)
    self.localTransform = self.localTransform:setTransformation(self.position[1], self.position[2], self.rotation, self.scale[1], self.scale[2], self.origin[1], self.origin[2])
end

local function UpdateGlobalTransform(self)
    if self.parent then
        self.globalTransform:setMatrix(self.parent.globalTransform:getMatrix())
    else
        self.globalTransform:setMatrix(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    end
    self.globalTransform:apply(self.localTransform)

    for _, child in ipairs(self.children) do
        UpdateGlobalTransform(child)
    end
end

local function UpdateGlobalAabbChildren(self)
    self.globalAabb:Set(self:GetAabb())
    local aabb = self.globalAabb
    for _, child in ipairs(self.children) do
        if child:IsEnable() then
            UpdateGlobalAabbChildren(child)
            aabb:AddAabb(child.globalAabb)
        end
    end
end

local function UpdateGlobalAabbParent(self)
    local parent = self:GetParent()
    while parent do
        parent.globalAabb:Set(parent:GetAabb())
        local aabb = parent.globalAabb
        for _, child in ipairs(parent.children) do
            if child:IsEnable() then
                aabb:AddAabb(child.globalAabb)
            end
        end
        parent = parent:GetParent()
    end
end

local function UpdateGlobalAabb(self)
    UpdateGlobalAabbChildren(self)
    UpdateGlobalAabbParent(self)
end

local function UpdateTransform(self)
    UpdateLocalTransform(self)
    UpdateGlobalTransform(self)
    UpdateGlobalAabb(self)
end

local function ResetLocalTransform(self)
    self.position = {
        0,
        0
    }
    self.scale = {
        1,
        1
    }
    self.rotation = 0
    self.origin = {
        0,
        0
    }
    UpdateLocalTransform(self)
end

function Control:TransformToLocal(x, y)
    return self.globalTransform:inverseTransformPoint(x, y)
end

function Control:TransformToGlobal(x, y)
    return self.globalTransform:transformPoint(x, y)
end

function Control:SetPosition(x, y)
    assert(x or y)
    if x then
        self.position[1] = x
    end
    if y then
        self.position[2] = y
    end
    UpdateTransform(self)
end

function Control:GetPosition()
    return unpack(self.position)
end

function Control:SetScale(scaleX, scaleY)
    assert(scaleX)
    scaleY = scaleY or scaleX
    self.scale[1] = scaleX
    self.scale[2] = scaleY
    UpdateTransform(self)
end

function Control:GetScale()
    return unpack(self.scale)
end

function Control:SetRotation(rotation)
    assert(rotation)
    self.rotation = rotation
    UpdateTransform(self)
end

function Control:GetRotation()
    return self.rotation
end

function Control:SetOrigin(x, y)
    assert(x or y)
    if x then
        self.origin[1] = x
    end
    if y then
        self.origin[2] = y
    end
    UpdateTransform(self)
end

function Control:GetOrigin()
    return unpack(self.origin)
end

function Control:AddChild(child)
    Tree.AddChild(self, child)
    UpdateGlobalTransform(child)
    UpdateGlobalAabb(child)
end

function Control:GetAabb()
    local w, h = self:GetSize()
    local aabb = Aabb()
    aabb:AddPoint(self:TransformToGlobal(0, 0))
    aabb:AddPoint(self:TransformToGlobal(w, 0))
    aabb:AddPoint(self:TransformToGlobal(w, h))
    aabb:AddPoint(self:TransformToGlobal(0, h))
    return aabb
end

local function GetRecursiveAabb(self, referenceTransform)
    local aabb = Aabb()
    local diff = referenceTransform:inverse():apply(self.globalTransform)
    local w, h = self:GetSize()

    aabb:AddPoint(diff:transformPoint(0, 0))
    aabb:AddPoint(diff:transformPoint(w, 0))
    aabb:AddPoint(diff:transformPoint(w, h))
    aabb:AddPoint(diff:transformPoint(0, h))
    for _, child in ipairs(self:GetChildren()) do
        aabb:AddAabb(GetRecursiveAabb(child, referenceTransform))
    end
    return aabb
end

function Control:GetRecursiveAabb(ctrl)
    ctrl = ctrl or self
    return GetRecursiveAabb(ctrl, self.globalTransform)
end

function Control:GetGlobalAabb()
    return self.globalAabb
end

function Control:SetSize(width, height)
    self.size[1], self.size[2] = width, height
    UpdateTransform(self)
end

function Control:GetSize()
    return unpack(self.size)
end

function Control:SetEnable(value)
    if self.parent then
        UpdateGlobalAabb(self.parent)
    end
    self.enable = value
end

function Control:IsEnable()
    return self.enable
end

function Control:SetVisible(value)
    self.visible = value
end

function Control:IsVisible()
    return self.enable and self.visible
end

function Control:Draw()
    local w, h = love.graphics:getDimensions()
    for _, child in ipairs(self.children) do
        local minX, minY, maxX, maxY = child.globalAabb:GetBounds()
        if child:IsVisible() and minX < w and maxX >= 0 and minY < h and maxY >= 0 then
            child:Draw()
        end
    end
end

function Control:Init(parent, width, height)
    self.enable = true
    self.visible = true

    self.localTransform = love.math.newTransform()
    self.globalTransform = love.math.newTransform()
    ResetLocalTransform(self)
    self.size = {
        width or 0,
        height or 0
    }
    self.globalAabb = Aabb()

    Tree.Init(self, parent)
end

MakeClassOf(Control, Tree)

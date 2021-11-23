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

function UpdateLocalTransform(self)
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
    local minX, minY, maxX, maxY = self:GetAabb()
    for _, child in ipairs(self.children) do
        UpdateGlobalAabbChildren(child)
        local childMinX, childMinY, childMaxX, childMaxY = unpack(child.globalAabb)
        minX, minY, maxX, maxY = math.min(minX, childMinX), math.min(minY, childMinY), math.max(maxX, childMaxX), math.max(maxY, childMaxY)
    end
    self.globalAabb = {
        minX,
        minY,
        maxX,
        maxY
    }
end

local function UpdateGlobalAabbParent(self)
    local parent = self:GetParent()
    while parent do
        local minX, minY, maxX, maxY = parent:GetAabb()
        for _, child in ipairs(parent.children) do
            local childMinX, childMinY, childMaxX, childMaxY = unpack(child.globalAabb)
            minX, minY, maxX, maxY = math.min(minX, childMinX), math.min(minY, childMinY), math.max(maxX, childMaxX), math.max(maxY, childMaxY)
            parent.globalAabb = {
                minX,
                minY,
                maxX,
                maxY
            }
        end
        parent = parent:GetParent()
    end
end

local function UpdateGlobalAabb(self)
    UpdateGlobalAabbChildren(self)
    UpdateGlobalAabbParent(self)
end

function Control:UpdateTransform()
    UpdateLocalTransform(self)
    UpdateGlobalTransform(self)
    UpdateGlobalAabb(self)
end

function Control:ResetLocalTransform()
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

function Control:GetGlobalScale()
    local scaleX, _, _, _, _, scaleY = self.globalTransform:getMatrix()
    return scaleX, scaleY
end

function Control:SetPosition(x, y)
    assert(x or y)
    if x then
        self.position[1] = x
    end
    if y then
        self.position[2] = y
    end
    self:UpdateTransform()
end

function Control:GetPosition()
    return unpack(self.position)
end

function Control:SetScale(scaleX, scaleY)
    assert(scaleX)
    scaleY = scaleY or scaleX
    self.scale[1] = scaleX
    self.scale[2] = scaleY
    self:UpdateTransform()
end

function Control:GetScale()
    return unpack(self.scale)
end

function Control:SetRotation(rotation)
    assert(rotation)
    self.rotation = rotation
    self:UpdateTransform()
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
    self:UpdateTransform()
end

function Control:GetOrigin()
    return unpack(self.origin)
end

function Control:AddChild(child)
    if child.parent then
        child.parent:RemoveChild(child)
    end
    child.parent = self
    table.insert(self.children, child)
    UpdateGlobalTransform(child)
    UpdateGlobalAabb(child)
end

function Control:RemoveChild(child)
    local found
    for i, v in ipairs(self.children) do
        if v == child then
            found = i
            break
        end
    end
    if found then
        table.remove(self.children, found)
        child.parent = nil
    else
        assert(false)
    end
end

function Control:GetChildren()
    return table.copy(self.children)
end

function Control:SetParent(parent)
    if parent then
        parent:AddChild(self)
    else
        if self.parent then
            self.parent:RemoveChild(self)
        end
    end
end

function Control:GetParent()
    return self.parent
end

function Control:Reattach(n)
    local children = self.parent.children
    n = n or #children
    local found
    for i, v in ipairs(children) do
        if v == self then
            found = i
            break
        end
    end
    if found then
        table.remove(children, found)
        table.insert(children, n, self)
    else
        assert(false)
    end
end

function Control:GetAabb()
    local w, h = self:GetSize()
    if w == 0 and h == 0 then
        return math.huge, math.huge, -math.huge, -math.huge
    end
    local x1, y1 = self:TransformToGlobal(0, 0)
    local x2, y2 = self:TransformToGlobal(w, 0)
    local x3, y3 = self:TransformToGlobal(w, h)
    local x4, y4 = self:TransformToGlobal(0, h)
    return math.min(x1, x2, x3, x4), math.min(y1, y2, y3, y4), math.max(x1, x2, x3, x4), math.max(y1, y2, y3, y4)
end

function Control:GetGlobalAabb()
    return unpack(self.globalAabb)
end

function Control:SetSize(width, height)
    self.size[1], self.size[2] = width, height
    self:UpdateTransform()
end

function Control:GetSize()
    return unpack(self.size)
end

function Control:SetEnable(value)
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
        local minX, minY, maxX, maxY = unpack(child.globalAabb)
        if child:IsVisible() and minX < w and maxX >= 0 and minY < h and maxY >= 0 then
            child:Draw()
        end
    end
end

function Control:Init(parent, width, height)
    self.enable = true
    self.visible = true
    self.children = {}

    self.localTransform = love.math.newTransform()
    self.globalTransform = love.math.newTransform()
    self:ResetLocalTransform()
    self.size = {
        width or 0,
        height or 0
    }
    self.globalAabb = {
        math.huge,
        math.huge,
        -math.huge,
        -math.huge
    }

    self.parent = nil
    if parent then
        self:SetParent(parent)
    end
end

MakeClassOf(Control)

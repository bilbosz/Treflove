Control = class("Control")

--[[
    Transformations
        Link: https://learnopengl.com/Getting-started/Transformations
        Order:
            Origin
            Scaling
            Rotation
            Position
]]

function Control:UpdateLocalTransform()
    self.localTransform = self.localTransform:setTransformation(self.position[1], self.position[2], self.rotation,
                              self.scale[1], self.scale[2], self.origin[1], self.origin[2])
end

function Control:UpdateGlobalTransform()
    if self.parent then
        self.globalTransform:setMatrix(self.parent.globalTransform:getMatrix())
    else
        self.globalTransform:setMatrix(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    end
    self.globalTransform:apply(self.localTransform)

    for _, child in ipairs(self.children) do
        child:UpdateGlobalTransform()
    end
end

function Control:UpdateGeometry()
    self:UpdateLocalTransform()
    self:UpdateGlobalTransform()
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
    self:UpdateGeometry()
end

function Control:GetPosition()
    return unpack(self.position)
end

function Control:SetScale(scaleX, scaleY)
    assert(scaleX)
    scaleY = scaleY or scaleX
    self.scale[1] = scaleX
    self.scale[2] = scaleY
    self:UpdateGeometry()
end

function Control:GetScale()
    return unpack(self.scale)
end

function Control:SetRotation(rotation)
    assert(rotation)
    self.rotation = rotation
    self:UpdateGeometry()
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
    self:UpdateGeometry()
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
    return self.children
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

function Control:GetAabb()
    return 0, 0, unpack(self.size)
end

function Control:GetGlobalAabb()
    local x1, y1 = self:TransformToGlobal(0, 0)
    local x2, y2 = self:TransformToGlobal(self:GetSize())
    return math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2)
end

function Control:GetSize()
    return unpack(self.size)
end

function Control:MousePressed(x, y, button)
    for _, child in ipairs(self.children) do
        child:MousePressed(x, y, button)
    end
end

function Control:MouseReleased(x, y, button)
    for _, child in ipairs(self.children) do
        child:MouseReleased(x, y, button)
    end
end

function Control:MouseMoved(x, y)
    for _, child in ipairs(self.children) do
        child:MouseMoved(x, y)
    end
end

function Control:WheelMoved(x, y)
    for _, child in ipairs(self.children) do
        child:WheelMoved(x, y)
    end
end

function Control:Update(dt)
    for _, child in ipairs(self.children) do
        child:Update(dt)
    end
end

function Control:Draw()
    for _, child in ipairs(self.children) do
        child:Draw()
    end
end

function Control:Init(parent, width, height)
    self.parent = nil
    if parent then
        self:SetParent(parent)
    end
    self.children = {}
    self.position = {0, 0}
    self.scale = {1, 1}
    self.rotation = 0
    self.origin = {0, 0}
    self.localTransform = love.math.newTransform()
    self.globalTransform = love.math.newTransform()
    self.size = {width or 0, height or 0}

    self:UpdateGlobalTransform()
end

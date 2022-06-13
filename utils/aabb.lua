Aabb = {}

function Aabb:Init()
    self.data = {
        math.huge,
        math.huge,
        -math.huge,
        -math.huge
    }
end

function Aabb:GetBounds()
    return unpack(self.data)
end

function Aabb:GetPositionAndSize()
    return self.data[1], self.data[2], self.data[3] - self.data[1], self.data[4] - self.data[2]
end

function Aabb:SetPositionAndSize(x, y, w, h)
    self.data[1], self.data[2], self.data[3], self.data[4] = x, y, x + w, y + h
end

function Aabb:GetMinX()
    return self.data[1]
end

function Aabb:GetMinY()
    return self.data[2]
end

function Aabb:GetMaxX()
    return self.data[3]
end

function Aabb:GetMaxY()
    return self.data[4]
end

function Aabb:AddPoint(x, y)
    local minX, minY, maxX, maxY = unpack(self.data)
    self.data = {
        math.min(minX, x),
        math.min(minY, y),
        math.max(maxX, x),
        math.max(maxY, y)
    }
end

function Aabb:AddAabb(other)
    assert_type(other, Aabb)
    local minX, minY, maxX, maxY = unpack(self.data)
    self.data = {
        math.min(minX, other.data[1]),
        math.min(minY, other.data[2]),
        math.max(maxX, other.data[3]),
        math.max(maxY, other.data[4])
    }
end

function Aabb:Set(other)
    self.data = table.copy(other.data)
end

function Aabb:Reset()
    self.data[1] = math.huge
    self.data[2] = math.huge
    self.data[3] = -math.huge
    self.data[4] = -math.huge
end

function Aabb:IsPointInside(x, y)
    local minX, minY, maxX, maxY = unpack(self.data)
    return x >= minX and x <= maxX and y >= minY and y <= maxY
end

function Aabb:GetWidth()
    return self.data[3] - self.data[1]
end

function Aabb:GetHeight()
    return self.data[4] - self.data[2]
end

function Aabb:Intersects(other)
    assert_type(other, Aabb)
    local aMinX, aMinY, aMaxX, aMaxY = unpack(self.data)
    local bMinX, bMinY, bMaxX, bMaxY = unpack(other.data)
    return aMinX <= bMaxX and aMinY <= bMaxY or aMaxX >= bMinX and aMaxY >= bMinY
end

function Aabb:GetPosition()
    return self.data[1], self.data[2]
end

function Aabb:GetSize()
    return self.data[3] - self.data[1], self.data[4] - self.data[2]
end

function Aabb:DoesCircleIntersect(x, y, r)
    if self:IsPointInside(x, y) then
        return true
    end
    local minX, minY, maxX, maxY = unpack(self.data)
    local cx = Clamp(minX, maxX, x)
    local cy = Clamp(minY, maxY, y)
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r
end

MakeClassOf(Aabb)

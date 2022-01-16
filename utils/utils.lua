function IsIdentifier(str)
    local l = #str
    local b, e = string.find(str, "[%a_][%w_]*")
    return b == 1 and e == l
end

function GetGlobalName(obj)
    for k, v in pairs(_G) do
        if v == obj then
            return k
        end
    end
end

function CreateIndex(self, ...)
    local idx = {}
    for i = select("#", ...), 1, -1 do
        table.merge(idx, getmetatable(select(i, ...)).__index)
    end
    table.merge(idx, self)
    return idx
end

local function DrawAabbsInternal(ctrl)
    local minX, minY, maxX, maxY = ctrl.globalAabb:GetBounds()
    love.graphics.rectangle("fill", minX, minY, maxX - minX, maxY - minY)
    for _, child in ipairs(ctrl.children) do
        if child:IsEnable() then
            DrawAabbs(child)
        end
    end
end

function DrawAabbs(ctrl)
    love.graphics.setColor({
        1,
        0,
        0,
        0.1
    })
    DrawAabbsInternal(ctrl)
    love.graphics.reset()
end

function Mix(a, b, x)
    return a + x * (b - a)
end

function GenerateSalt(length)
    local result = ""
    local rng = love.math.newRandomGenerator()
    rng:setSeed(app.isServer and Consts.SERVER_SEED or Consts.CLIENT_SEED)
    for _ = 0, length do
        result = result .. string.char(rng:random(0, 255))
    end
    return love.data.encode("string", "base64", result)
end

function Hash(str)
    return love.data.encode("string", "base64", love.data.hash(Consts.HASH_ALGORITHM, str))
end

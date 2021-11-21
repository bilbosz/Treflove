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
    local minX, minY, maxX, maxY = unpack(ctrl.globalAabb)
    love.graphics.rectangle("fill", minX, minY, maxX - minX, maxY - minY)
    for _, child in ipairs(ctrl.children) do
        if child:IsEnabled() then
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

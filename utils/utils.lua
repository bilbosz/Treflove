local socket = require("socket")

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

local function DrawAabbsInternal(ctrl)
    love.graphics.rectangle("fill", ctrl.globalAabb:GetPositionAndSize())
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

function Clamp(min, max, x)
    return math.min(math.max(min, x), max)
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

function GetTime()
    return socket.gettime()
end

function GetStacktrace(minLevel)
    minLevel = minLevel or 1
    local trace = ""
    local up = 1
    local level = 1
    while true do
        local info = debug.getinfo(up, "nSl")
        if not info then
            break
        end
        if string.sub(info.source, 1, 1) == "@" then
            if level >= minLevel + 1 then
                local location = string.format("%s:%i", info.short_src, info.currentline)
                if info.short_src ~= "utils/class.lua" then
                    if info.name then
                        trace = trace .. string.format("%44s in %s %s", location, info.namewhat, info.name) .. "\n"
                    else
                        trace = trace .. string.format("%44s", location) .. "\n"
                    end
                end
            end
            level = level + 1
        end
        up = up + 1
    end
    return trace
end

function abstract()
    assert(false, "Method marked as abstract has no implementation")
end

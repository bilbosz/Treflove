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

function GetStacktrace()
    local result = ""
    local trace = debug.traceback()
    local lineNo = 1
    local ignoreHead = 3
    local found = 0
    while found do
        local prev = found
        found = string.find(trace, "\n", found + 1)
        local line = string.sub(trace, prev + 1, found)
        if lineNo > ignoreHead and not string.find(line, "boot%.lua") and not string.find(line, "%[.+%]") and not string.find(line, "utils/class.lua") then
            result = result .. line
        end
        lineNo = lineNo + 1
    end
    return result
end

function abstract()
    assert(false, "Method marked as abstract has no implementation")
end

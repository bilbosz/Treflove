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

function DumpControls(ctrl, indent)
    indent = indent or ""
    local name = GetClassNameOf(ctrl)
    local result = indent .. name .. "[" .. (ctrl:IsEnabled() and "e" or " ") .. (ctrl:IsVisible() and "v" or " ") .. (ctrl:AllPredecessorsEnabled() and "a" or " ") .. "]" .. "\n"
    for _, child in ipairs(ctrl:GetChildren()) do
        result = result .. DumpControls(child, indent .. "|   ")
    end
    return result
end

function MonitorObject(obj, blackFunctions)
    blackFunctions = blackFunctions or {}
    local mt = getmetatable(obj)
    local oldIndex = mt.__index
    mt.__index = function(t, k)
        local level = 1
        local info = debug.getinfo(level, "f")
        while info do
            local f = info.func
            if table.findidx(blackFunctions, f) then
                return oldIndex[k]
            end
            level = level + 1
            info = debug.getinfo(level, "f")
        end
        app:Log("Read on " .. k)
        return oldIndex[k]
    end
    mt.__newindex = function(t, k, v)
        oldIndex[k] = v
        app:Log("Write on " .. k)
    end
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

function SplitPath(path)
    local result = {}
    local lastFound, found = 1, 0
    while true do
        found = string.find(path, "/", found + 1)
        if not found then
            break
        end

        local split = string.sub(path, lastFound + 1, found - 1)
        table.insert(result, split)

        lastFound = found
    end

    local split = string.sub(path, lastFound + 1, #path)
    table.insert(result, split)

    return result
end

function abstract()
    assert(false, "Method marked as abstract has no implementation")
end
